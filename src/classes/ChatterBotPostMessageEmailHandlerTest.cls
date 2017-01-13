/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/salesforce-chatter-bot-feeds
 *
 * Unfortunately, when testing ConnectApi methods Salesforce requires SeeAllData = true.
 * If you don't then you'll get an error: "System.UnsupportedOperationException: ConnectApi methods are not supported in data siloed tests. Please use @IsTest(SeeAllData=true)."
 */
@isTest( seeAllData = true )
private class ChatterBotPostMessageEmailHandlerTest {

    @isTest( seeAllData = true )
    static void test_post_message() {

        CollaborationGroup grp = new CollaborationGroup(
            name = 'Test Group ' + DateTime.now().getTime(),
            collaborationType = 'Public'
        );

        insert grp;

        ChatterBotPostMessageInvocable.Request req = new ChatterBotPostMessageInvocable.Request();
        req.authorId = UserInfo.getUserId();
        req.subjectId = grp.id;
        req.recordId = UserInfo.getUserId();
        req.emailTemplateName = 'Chatter_Bot_Post_Message_Template';

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Chatter Bot Post Message';
        email.plainTextBody = JSON.serialize( req );

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( true, result.success );

        FeedItem fi = [ SELECT id, parentId, body FROM FeedItem WHERE parentId = :grp.id LIMIT 1 ];

        System.debug( fi );

    }

    @isTest( seeAllData = true )
    static void test_missing_authorId() {

        CollaborationGroup grp = new CollaborationGroup(
            name = 'Test Group ' + DateTime.now().getTime(),
            collaborationType = 'Public'
        );

        insert grp;

        ChatterBotPostMessageInvocable.Request req = new ChatterBotPostMessageInvocable.Request();
        req.authorId = null;
        req.subjectId = grp.id;
        req.recordId = UserInfo.getUserId();
        req.emailTemplateName = 'Chatter_Bot_Post_Message_Template';

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Chatter Bot Post Message';
        email.plainTextBody = JSON.serialize( req );

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( false, result.success );
        System.assert( result.message.contains( 'Missing "authorId"' ) );

    }

    @isTest( seeAllData = true )
    static void test_missing_subjectId() {

        CollaborationGroup grp = new CollaborationGroup(
            name = 'Test Group ' + DateTime.now().getTime(),
            collaborationType = 'Public'
        );

        insert grp;

        ChatterBotPostMessageInvocable.Request req = new ChatterBotPostMessageInvocable.Request();
        req.authorId = UserInfo.getUserId();
        req.subjectId = null;
        req.recordId = UserInfo.getUserId();
        req.emailTemplateName = 'Chatter_Bot_Post_Message_Template';

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Chatter Bot Post Message';
        email.plainTextBody = JSON.serialize( req );

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( false, result.success );
        System.assert( result.message.contains( 'Missing "subjectId"' ) );

    }

    @isTest( seeAllData = true )
    static void test_missing_template() {

        CollaborationGroup grp = new CollaborationGroup(
            name = 'Test Group ' + DateTime.now().getTime(),
            collaborationType = 'Public'
        );

        insert grp;

        ChatterBotPostMessageInvocable.Request req = new ChatterBotPostMessageInvocable.Request();
        req.authorId = UserInfo.getUserId();
        req.subjectId = grp.id;
        req.recordId = UserInfo.getUserId();
        req.emailTemplateName = String.valueOf( DateTime.now().getTime() ); // doesn't exist

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Chatter Bot Post Message';
        email.plainTextBody = JSON.serialize( req );

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( false, result.success );
        System.assert( result.message.contains( 'No email template found' ) );

    }

    @isTest( seeAllData = true )
    static void test_missing_message() {

        CollaborationGroup grp = new CollaborationGroup(
            name = 'Test Group ' + DateTime.now().getTime(),
            collaborationType = 'Public'
        );

        insert grp;

        ChatterBotPostMessageInvocable.Request req = new ChatterBotPostMessageInvocable.Request();
        req.authorId = UserInfo.getUserId();
        req.subjectId = grp.id;
        req.recordId = UserInfo.getUserId();
        req.emailTemplateName = null;

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Chatter Bot Post Message';
        email.plainTextBody = JSON.serialize( req );

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( false, result.success );
        System.assert( result.message.contains( 'One of either "message" or "emailTemplateName"' ) );

    }

}