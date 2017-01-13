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

        ChatterBotPostMessageInvocable.Request req = (ChatterBotPostMessageInvocable.Request) JSON.deserialize( email.plainTextBody, ChatterBotPostMessageInvocable.Request.class );

        System.debug( req );

        String authorId = req.authorId;     // who is posting the message
        String subjectId = req.subjectId;   // where the post is being made: user, group, record
        String recordId = req.recordId;     // if using email template, the record used to satisfy merge fields
        String message = req.message;       // if not using email template, the chatter message to post
        String emailTemplateName = req.emailTemplateName;

        if ( String.isBlank( authorId ) ) {
            throw new ChatterBotPostMessageException( 'Missing "authorId" to indicate which user is authoring this Chatter post.' );
        }

        if ( String.isBlank( subjectId ) ) {
            throw new ChatterBotPostMessageException( 'Missing "subjectId" to indicate where to post this message: User, Group, or Record ID.' );
        }

        if ( String.isNotBlank( emailTemplateName ) ) {

            List<EmailTemplate> templates = new List<EmailTemplate>([ SELECT id, body FROM EmailTemplate WHERE developerName = :emailTemplateName LIMIT 1 ]);

            if ( templates.size() == 0 ) {
                throw new ChatterBotPostMessageException( 'No email template found by unique name: ' + emailTemplateName );
            }

            Messaging.SingleEmailMessage emailMessage = Messaging.renderStoredEmailTemplate( templates[0].id, authorId, recordId );

            message = emailMessage.getHtmlBody();

        }

        if ( String.isBlank( message ) ) {
            throw new ChatterBotPostMessageException( 'One of either "message" or "emailTemplateName" must be provided as the content of the Chatter post.' );
        }

        String networkId = getNetworkIdForSubject( subjectId );

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

    private ID getNetworkIdForSubject( String subjectId ) {

        System.debug( 'getting network id for subject id: ' + subjectId );

        String networkId = null;

        DescribeSObjectResult groupDescribe = CollaborationGroup.sObjectType.getDescribe();
        Map<String, SObjectField> groupFieldsMap = groupDescribe.fields.getMap();

        Boolean subjectIdIsGroup = ( groupDescribe.getKeyPrefix() == subjectId.left( 3 ) );
        Boolean groupHasNetworkId = ( groupFieldsMap.containsKey( 'NetworkId' ) );

        System.debug( 'subjectIdIsGroup: ' + subjectIdIsGroup );
        System.debug( 'groupHasNetworkId: ' + groupHasNetworkId );

        // if posting to a group and the group belongs to a specific community then
        // we will use that as the network id. Note, the NetworkId field only exists
        // if an org has a community created.
        if ( subjectIdIsGroup && groupHasNetworkId ) {

            // since an org may or may not have NetworkId field available
            // depending on if they have a community or not then we need
            // to use dynamic query to avoid compilation issues
            for ( CollaborationGroup grp : Database.query( 'SELECT networkId FROM CollaborationGroup WHERE id = :subjectId LIMIT 1' ) ) {

                Object fieldValue = grp.get( 'networkId' );

                if ( fieldValue != null ) {
                    networkId = String.valueOf( fieldValue );
                }

            }

        }

        if ( String.isBlank( networkId ) ) {
            System.debug( 'Group does not have a NetworkId, using default Network.getNetWorkId()' );
            networkId = Network.getNetworkId();
        }

        System.debug( 'networkId: ' + networkId );

        return networkId;
    }

    public class ChatterBotPostMessageException extends Exception {}

}