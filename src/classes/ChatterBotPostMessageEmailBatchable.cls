/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/salesforce-chatter-bot-feeds
 */
public with sharing class ChatterBotPostMessageEmailBatchable implements Database.Batchable<ChatterBotPostMessageInvocable.Request>, Database.Stateful {

    private List<ChatterBotPostMessageInvocable.Request> requests { get; set; }

    public ChatterBotPostMessageEmailBatchable( List<ChatterBotPostMessageInvocable.Request> requests ) {
        this.requests = requests;
    }

    public List<ChatterBotPostMessageInvocable.Request> start( Database.BatchableContext context ) {

        System.debug( 'ChatterBotPostMessageEmailBatchable.start: ' + context );

        return this.requests;
    }

    public void execute( Database.BatchableContext context, List<ChatterBotPostMessageInvocable.Request> requests ) {

        System.debug( 'ChatterBotPostMessageEmailBatchable.execute: ' + context );

        Chatter_Bot_Feeds_Setting__c settings = Chatter_Bot_Feeds_Setting__c.getInstance();

        Boolean allOrNone = false;

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();

        for ( ChatterBotPostMessageInvocable.Request req : requests ) {
            messages.add( convertToMessage( req, settings ) );
        }

        List<Messaging.SendEmailResult> results = Messaging.sendEmail( messages, allOrNone );

        for ( Messaging.SendEmailResult result : results ) {
            if ( !result.isSuccess() ) {
                for ( Messaging.SendEmailError err : result.getErrors() ) {
                    System.debug( LoggingLevel.ERROR, err );
                }
            }
        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'ChatterBotPostMessageEmailBatchable.finish: ' + context );

    }

    // -----------------------------------------------------------------

    private static Messaging.SingleEmailMessage convertToMessage( ChatterBotPostMessageInvocable.Request req, Chatter_Bot_Feeds_Setting__c settings ) {

        if ( String.isBlank( settings.email_service_address__c ) ) {
            throw new ChatterBotPostMessageException( 'Missing Chatter_Bot_Feeds_Setting__c.Email_Service_Address__c. Please update custom setting with email service address for ChatterBotPostMessageEmailHandler.' );
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();

        message.setToAddresses( new String[] { settings.email_service_address__c } );
        message.setPlainTextBody( JSON.serialize( req ) );

        return message;
    }

    // -----------------------------------------------------------------

    public class ChatterBotPostMessageException extends Exception {}

}