/**
 * Developed by Doug Ayers
 * douglascayers.com
 *
 * Unfortunately, when testing ConnectApi methods Salesforce requires SeeAllData = true.
 * If you don't then you'll get an error: "System.UnsupportedOperationException: ConnectApi methods are not supported in data siloed tests. Please use @IsTest(SeeAllData=true)."
 */
@isTest( seeAllData = true )
private class ChatterBotPostMessageEmailHandlerTest {

    @isTest( seeAllData = true )
    static void test_missing_subjectId() {

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Test Email';
        email.plainTextBody = '';
        email.fromName = 'Tester';
        email.fromAddress = 'test@example.com';
        email.ccAddresses = new String[] { 'ceo@salesforce.com' };

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( false, result.success );
        System.assert( result.message.contains( 'Missing "subjectId=<user, group, or record id>" in email body.' ) );

    }

    @isTest( seeAllData = true )
    static void test_missing_message() {

        CollaborationGroup grp = new CollaborationGroup(
            name = 'Test Group',
            collaborationType = 'Public'
        );

        insert grp;

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Test Email';
        email.plainTextBody = 'subjectId=' + grp.id;
        email.fromName = 'Tester';
        email.fromAddress = 'test@example.com';
        email.ccAddresses = new String[] { 'ceo@salesforce.com' };

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( false, result.success );
        System.assert( result.message.contains( 'Missing "message=<text>" in email body.' ) );

    }

    @isTest( seeAllData = true )
    static void test_post_message() {

        CollaborationGroup grp = new CollaborationGroup(
            name = 'Test Group ' + DateTime.now().getTime(),
            collaborationType = 'Public'
        );

        insert grp;

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Test Email';
        email.plainTextBody = 'subjectId=' + grp.id + '\n' + 'message=Hello {' + UserInfo.getUserId() + '}';
        email.fromName = 'Tester';
        email.fromAddress = 'test@example.com';
        email.ccAddresses = new String[] { 'ceo@salesforce.com' };

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( true, result.success );

        FeedItem fi = [ SELECT id, parentId, body FROM FeedItem WHERE parentId = :grp.id LIMIT 1 ];

        System.debug( fi );
        System.assert( fi.body.contains( '@' + UserInfo.getName() ) );

    }

}