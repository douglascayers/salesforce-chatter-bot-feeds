/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/salesforce-chatter-bot-feeds
 */
public without sharing class ChatterBotPostMessageInvocable {

    @InvocableMethod(
        label = 'CB: Post Message'
        description = 'Posts a Chatter message as specified user.'
    )
    public static void execute( List<Request> requests ) {

        System.debug( 'ChatterBotPostMessageInvocable.execute: ' + requests );

        Chatter_Bot_Feeds_Setting__c settings = Chatter_Bot_Feeds_Setting__c.getInstance();

        if ( String.isBlank( settings.email_service_address_user_id__c ) ) {
            throw new ChatterBotPostMessageException( 'Missing Chatter_Bot_Feeds_Setting__c.Email_Service_Address_User_ID__c. Please update custom setting with email service address for ChatterBotPostMessageEmailHandler.' );
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setTargetObjectId( settings.email_service_address_user_id__c );
        message.setTreatTargetObjectAsRecipient( true );
        message.setSaveAsActivity( false );
        message.setPlainTextBody( JSON.serialize( requests ) );

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        messages.add( message );

        Boolean allOrNone = false;

        List<Messaging.SendEmailResult> results = Messaging.sendEmail( messages, allOrNone );

        for ( Messaging.SendEmailResult result : results ) {
            if ( !result.isSuccess() ) {
                for ( Messaging.SendEmailError err : result.getErrors() ) {
                    System.debug( LoggingLevel.ERROR, err );
                }
            }
        }

    }

    // -----------------------------------------------------------------

    public class Request {

        @InvocableVariable(
            label = 'Author User ID'
            description = 'Who the Chatter post will be shown as created by.'
            required = true
        )
        public String authorId;

        @InvocableVariable(
            label = 'User, Group, or Record ID'
            description = 'Where the Chatter post will be made.'
            required = true
        )
        public String subjectId;

        @InvocableVariable(
            label = 'Chatter Message'
            description = 'The message to post. One of "Chatter Message" or "Email Template Unique Name" must be specified.'
        )
        public String message;

        @InvocableVariable(
            label = 'Email Template Unique Name'
            description = 'An email template to use for generating the rich-text Chatter post message. One of "Chatter Message" or "Email Template Unique Name" must be specified.'
        )
        public String emailTemplateName;

        @InvocableVariable(
            label = 'Record ID (Template Merge Fields)'
            description = 'Identifies a record such as an Account or Contact that will be read and used in merge field processing of the email template.'
        )
        public String recordId;

    }

    // -----------------------------------------------------------------

    public class ChatterBotPostMessageException extends Exception {}

}