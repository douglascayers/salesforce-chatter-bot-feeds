/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/salesforce-chatter-bot-feeds
 */
public without sharing class ChatterBotPostMessageService {

    private static final String FEED_ITEM_KEY_PREFIX = FeedItem.sObjectType.getDescribe().getKeyPrefix();

    public void processRequests( List<ChatterBotPostMessageInvocable.Request> requests ) {

        System.debug( 'processing requests' );

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

    // -----------------------------------------------------

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

    /**
     * Determines if we should post a FeedItem or FeedComment based on the subject id.
     * If the subject is itself a Chatter FeedItem then we will post a comment to that thread.
     * Otherwise we post a new Chatter message.
     */
    private void postChatterMessage( ID networkId, ID authorId, ID subjectId, String message ) {

        System.debug( 'posting chatter message: networkId=' + networkId + ', authorId=' + authorId + ', subjectId=' + subjectId + ', message=' + message );

        // if message uses Flow or Process Builder @mention syntax @[user_or_group_id]
        // unfortunately the ConnectApi doesn't support that. It won't error, but won't
        // resolve to an expected @mention. So we need to translate that syntax into
        // the syntax expected by ConnectApi, which is simply {user_or_group_id}.
        // Now, you might say, well, tell folks to use that new syntax instead.
        // Unfortunately, if you try to use that {id} syntax in a Flow Text Template
        // then it misinterprets and tries to pre-emptively resolve the variable and
        // results in {Notfound} rendered. Not what we want....
        Matcher mentionMatcher = Pattern.compile( '(@\\[([a-zA-Z0-9]+)\\])' ).matcher( message );
        while ( mentionMatcher.find() ) {
            message = mentionMatcher.replaceAll( '{$2}' );
        }

        String subjectKeyPrefix = String.valueOf( subjectId ).left( 3 );

        if ( subjectKeyPrefix == FEED_ITEM_KEY_PREFIX ) {
            postFeedComment( networkId, authorId, subjectId, message );
        } else {
            postFeedItem( networkId, authorId, subjectId, message );
        }

    }

    /**
     * Posts a new message related to given subject.
     * SubjectId must not be another FeedItem or FeedComment but rather
     * a User ID, Chatter Group ID, or other record ID like an Account, Contact, etc.
     */
    private void postFeedItem( ID networkId, ID authorId, ID subjectId, String message ) {

        System.debug( 'posting feed item: networkId=' + networkId + ', authorId=' + authorId + ', subjectId=' + subjectId + ', message=' + message );

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

    /**
     * Posts a comment to an existing feed item.
     * SubjectId must be ID of a FeedItem record.
     */
    private void postFeedComment( ID networkId, ID authorId, ID subjectId, String message ) {

        System.debug( 'posting feed comment: networkId=' + networkId + ', authorId=' + authorId + ', subjectId=' + subjectId + ', message=' + message );

        // we use a mix of FeedComment DML and ConnectApi for our requirements:
        // 1. Post Chatter Message as any user (FeedComment DML)
        // 2. Post Rich-Text content with @mentions (ConnectApi)

        // setting the createdById only works if the context user of this email service
        // has the system permission "Insert System Field Values for Chatter Feeds"

        // even though rich-text is supported with FeedComment DML,
        // all @mention links are converted to plain text.
        // workaround is that after inserting the FeedComment we use ConnectApi
        // to update the element with the same rich-text but @mentions will be preserved.

        FeedComment fc = new FeedComment(
            feedItemId = subjectId,     // where post is being made: user, group, record
            createdById = authorId,     // who is posting the message
            commentBody = message,      // rich-text, but @mentions not supported
            isRichText = true           // we support rich-text and @mentions
        );

        insert fc;

        System.debug( fc );

        // after creating the shell of the feed comment, retrieve the record back in Chatter for Apex
        ConnectApi.Comment comment = ConnectApi.ChatterFeeds.getComment( networkId, fc.id );

        // parse the rich-text message and create new message input
        ConnectApi.MessageBodyInput messageInput = new ConnectApi.MessageBodyInput();
        messageInput.messageSegments = ConnectApiHelper.getMessageSegmentInputs( message );

        // define an updated feed element using the rich-text message
        ConnectApi.CommentInput input = new ConnectApi.CommentInput();
        input.body = messageInput;

        // replace the content of the chatter post
        comment = ConnectApi.ChatterFeeds.updateComment( networkId, comment.id, input );

        System.debug( comment );

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