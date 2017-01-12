/**
 * Developed by Doug Ayers
 * douglascayers.com
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

            System.debug( LoggingLevel.ERROR, e.getStackTraceString() );

            result.message = e.getMessage() + '\n' + e.getStackTraceString();
            result.success = false;

        }

        if ( result.success == false ) {
            if ( sp != null ) {
                System.debug( 'Rolling back transaction' );
                Database.rollback( sp );
            }
        }

        return result;
    }

    // -------------------------------------------------------------------------

    private void processEmail( Messaging.InboundEmail email ) {

        System.debug( 'processing email' );

        String subjectId = parseSubjectId( email );
        String message = parseMessage( email );

        if ( String.isBlank( subjectId ) ) {
            throw new ChatterBotPostMessageException( 'Missing "subjectId=<user, group, or record id>" in email body.' );
        }

        if ( String.isBlank( message ) ) {
            throw new ChatterBotPostMessageException( 'Missing "message=<text>" in email body.' );
        }

        String networkId = getNetworkIdForSubject( subjectId );

        System.debug( 'posting feed item: networkId=' + networkId + ', subjectId=' + subjectId + ', message=' + message );

        // I am eternally grateful for the ConnectApiHelper
        // one line and rich text chatter message with @mentions created, yeah!
        // https://github.com/forcedotcom/ConnectApiHelper
        ConnectApi.FeedItem fi = (ConnectApi.FeedItem) ConnectApiHelper.postFeedItemWithMentions( networkId, subjectId, message );

        System.debug( fi );

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

    private String parseSubjectId( Messaging.InboundEmail email ) {

        String regex = 'subjectId=(.*)';
        String body = ( String.isBlank( email.htmlBody ) ? email.plainTextBody : email.htmlBody );

        System.debug( 'Checking email body for subject id: regex=' + regex + ', body=' + body );

        String subjectId = parseAndFindFirstMatch( body, regex );

        System.debug( 'subject id: ' + subjectId );

        return subjectId;
    }

    private String parseMessage( Messaging.InboundEmail email ) {

        String regex = 'message=((.*\\s*)+)';
        String body = ( String.isBlank( email.htmlBody ) ? email.plainTextBody : email.htmlBody );

        System.debug( 'Checking email body for message: regex=' + regex + ', body=' + body );

        String message = parseAndFindFirstMatch( body, regex );

        // if message parsed from html body then it may be terminated with </html>
        message = message.replace( '</html>', '' );

        System.debug( 'message: ' + message );

        return message;
    }

    /**
     * Parses a string using regular expression and returns first grouping match.
     */
    private String parseAndFindFirstMatch( String text, String regex ) {

        String value = '';
        Pattern myPattern = Pattern.compile( regex );
        Matcher myMatcher = myPattern.matcher( text );

        if ( myMatcher.find() ) {
            value = myMatcher.group(1).trim();
        }

        return value;
    }

    public class ChatterBotPostMessageException extends Exception {}

}