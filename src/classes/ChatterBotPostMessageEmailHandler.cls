/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/salesforce-chatter-bot-feeds
 *
 * https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_ConnectAPI_ChatterFeeds_static_methods.htm#apex_ConnectAPI_ChatterFeeds_postFeedElement_3
 * https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/connectapi_examples_post_feed_element_mention.htm
 * https://github.com/forcedotcom/ConnectApiHelper
 */
public with sharing class ChatterBotPostMessageEmailHandler implements Messaging.InboundEmailHandler {

    public Messaging.InboundEmailResult handleInboundEmail( Messaging.InboundEmail email, Messaging.InboundEnvelope envelope ) {

        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        SavePoint sp = Database.setSavePoint();

        try {

            System.debug( 'Handling inbound email: ' + email );
            System.debug( envelope );

            processEmail( email );

            // if result is false then salesforce does not commit DML changes
            result.success = true;

        } catch ( Exception e ) {

            System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

            result.message = e.getMessage() + '\n' + e.getStackTraceString();
            result.success = false;

        }

        if ( result.success == false ) {
            if ( sp != null ) {
                System.debug( LoggingLevel.ERROR, 'Rolling back transaction' );
                Database.rollback( sp );
            }
        }

        return result;
    }

    // -------------------------------------------------------------------------

    private void processEmail( Messaging.InboundEmail email ) {

        System.debug( 'processing email' );

        List<ChatterBotPostMessageInvocable.Request> requests = (List<ChatterBotPostMessageInvocable.Request>) JSON.deserialize( email.plainTextBody, List<ChatterBotPostMessageInvocable.Request>.class );

        Set<String> emailTemplateNames = new Set<String>();
        Set<ID> subjectIds = new Set<ID>();

        for ( ChatterBotPostMessageInvocable.Request request : requests ) {

            if ( String.isNotBlank( request.emailTemplateName ) ) {
                emailTemplateNames.add( request.emailTemplateName );
            }

            if ( String.isNotBlank( request.subjectId ) ) {
                subjectIds.add( request.subjectId );
            }

        }

        Map<String, ID> emailTemplateNameToIdMap = queryEmailTemplateNameToIdMap( emailTemplateNames );
        Map<ID, ID> subjectIdToNetworkIdMap = querySubjectIdToNetworkIdMap( subjectIds );

        for ( ChatterBotPostMessageInvocable.Request request : requests ) {
            processRequest( request, emailTemplateNameToIdMap, subjectIdToNetworkIdMap );
        }

    }

    private void processRequest( ChatterBotPostMessageInvocable.Request request, Map<String, ID> emailTemplateNameToIdMap, Map<ID, ID> subjectIdToNetworkIdMap ) {

        System.debug( 'processing request: ' + request );

        String authorId = request.authorId;     // who is posting the message
        String subjectId = request.subjectId;   // where the post is being made: user, group, record
        String recordId = request.recordId;     // if using email template, the record used to satisfy merge fields
        String message = request.message;       // if not using email template, the chatter message to post
        String emailTemplateName = request.emailTemplateName;
        String networkId = Network.getNetworkId();

        if ( String.isBlank( authorId ) ) {
            throw new ChatterBotPostMessageException( 'Missing "authorId" to indicate which user is authoring this Chatter post.' );
        }

        if ( String.isBlank( subjectId ) ) {
            throw new ChatterBotPostMessageException( 'Missing "subjectId" to indicate where to post this message: User, Group, or Record ID.' );
        } else {
            networkId = subjectIdToNetworkIdMap.get( subjectId );
        }

        if ( String.isNotBlank( emailTemplateName ) ) {

            ID emailTemplateId = emailTemplateNameToIdMap.get( emailTemplateName );

            if ( String.isBlank( emailTemplateId ) ) {
                throw new ChatterBotPostMessageException( 'No email template found by unique name: ' + emailTemplateName );
            }

            Messaging.SingleEmailMessage emailMessage = Messaging.renderStoredEmailTemplate( emailTemplateId, authorId, recordId );

            message = emailMessage.getHtmlBody();

        }

        if ( String.isBlank( message ) ) {
            throw new ChatterBotPostMessageException( 'One of either "message" or "emailTemplateName" must be provided as the content of the Chatter post.' );
        }

        postChatterMessage( networkId, authorId, subjectId, message );

    }

    private void postChatterMessage( ID networkId, ID authorId, ID subjectId, String message ) {

        System.debug( 'posting chatter message: networkId=' + networkId + ', authorId=' + authorId + ', subjectId=' + subjectId + ', message=' + message );

        // we use a mix of FeedItem DML and ConnectApi for our requirements:
        // 1. Post Chatter Message as any user (FeedItem DML)
        // 2. Post Rich-Text content with @mentions (ConnectApi)

        // setting the createdById only works if the context user of this email service
        // has the system permission "Insert System Field Values for Chatter Feeds"

        // even though rich-text is supported with FeedItem DML,
        // all @mention links are converted to plain text.
        // workaround is that after inserting the FeedItem we use ConnectApi
        // to update the element with the same rich-text but @mentions will be preserved.

        FeedItem fi = new FeedItem(
            parentId = subjectId,       // where post is being made: user, group, record
            createdById = authorId,     // who is posting the message
            body = message,             // rich-text, but @mentions not supported
            isRichText = true           // we support rich-text and @mentions
        );

        insert fi;

        System.debug( fi );

        // after creating the shell of the feed item, retrieve the record back in Chatter for Apex
        ConnectApi.FeedElement fe = ConnectApi.ChatterFeeds.getFeedElement( networkId, fi.id );

        // parse the rich-text message and create new message input
        ConnectApi.MessageBodyInput messageInput = new ConnectApi.MessageBodyInput();
        messageInput.messageSegments = ConnectApiHelper.getMessageSegmentInputs( message );

        // define an updated feed element using the rich-text message
        ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
        input.body = messageInput;

        // replace the content of the chatter post
        fe = ConnectApi.ChatterFeeds.updateFeedElement( networkId, fe.id, input );

        System.debug( fe );

    }

    private Map<String, ID> queryEmailTemplateNameToIdMap( Set<String> emailTemplateNames ) {

        System.debug( 'building email template map' );
        System.debug( 'emailTemplateNames=' + emailTemplateNames );

        Map<String, ID> emailTemplateNameToIdMap = new Map<String, ID>();

        if ( emailTemplateNames.size() > 0 ) {

            List<EmailTemplate> templates = new List<EmailTemplate>([
                SELECT
                    id, developerName
                FROM
                    EmailTemplate
                WHERE
                    developerName IN :emailTemplateNames
            ]);

            for ( EmailTemplate template : templates ) {
                emailTemplateNameToIdMap.put( template.developerName, template.id );
            }

        }

        return emailTemplateNameToIdMap;
    }

    private Map<ID, ID> querySubjectIdToNetworkIdMap( Set<ID> subjectIds ) {

        System.debug( 'building subject => network map' );
        System.debug( 'subjectIds=' + subjectIds );

        Map<ID, ID> subjectIdToNetworkIdMap = new Map<ID, ID>();

        DescribeSObjectResult groupDescribe = CollaborationGroup.sObjectType.getDescribe();
        Map<String, SObjectField> groupFieldsMap = groupDescribe.fields.getMap();
        Boolean groupHasNetworkId = ( groupFieldsMap.containsKey( 'NetworkId' ) );

        System.debug( 'groupHasNetworkId: ' + groupHasNetworkId );

        // if posting to a group and the group belongs to a specific community then
        // we will use that as the network id. Note, the NetworkId field only exists
        // if an org has a community created.
        if ( groupHasNetworkId ) {

            // since an org may or may not have NetworkId field available
            // depending on if they have a community or not then we need
            // to use dynamic query to avoid compilation issues
            for ( CollaborationGroup grp : Database.query( 'SELECT id, networkId FROM CollaborationGroup WHERE id IN :subjectIds' ) ) {

                Object fieldValue = grp.get( 'networkId' );

                if ( fieldValue != null ) {
                    subjectIdToNetworkIdMap.put( grp.id, String.valueOf( fieldValue ) );
                }

            }

        }

        return subjectIdToNetworkIdMap;
    }

    public class ChatterBotPostMessageException extends Exception {}

}