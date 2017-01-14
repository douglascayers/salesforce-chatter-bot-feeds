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

        new ChatterBotPostMessageService().processRequests( requests );

    }

}