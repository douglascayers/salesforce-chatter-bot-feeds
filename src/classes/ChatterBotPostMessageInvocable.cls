/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/salesforce-chatter-bot-feeds
 */
public with sharing class ChatterBotPostMessageInvocable {

    @InvocableMethod(
        label = 'CB: Post Message'
        description = 'Posts a Chatter message as specified user.'
    )
    public static void execute( List<Request> requests ) {

        System.debug( 'ChatterBotPostMessageInvocable.execute: ' + requests );

        Database.executeBatch( new ChatterBotPostMessageEmailBatchable( requests ), Limits.getLimitEmailInvocations() );

    }

    // -----------------------------------------------

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
            description = 'The message to post. One of "Chatter Message" or "Email Template Name" must be specified.'
        )
        public String message;

        @InvocableVariable(
            label = 'Email Template Unique Name'
            description = 'An email template to use for generating the rich-text Chatter post message. One of "Chatter Message" or "Email Template Name" must be specified.'
        )
        public String emailTemplateName;

        @InvocableVariable(
            label = 'Record ID (Template Merge Fields)'
            description = 'Identifies a record such as an Account or Contact that will be read and used in merge field processing of the email template.'
        )
        public String recordId;

    }

}