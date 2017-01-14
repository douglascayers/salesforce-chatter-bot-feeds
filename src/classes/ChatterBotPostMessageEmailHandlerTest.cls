/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/salesforce-chatter-bot-feeds
 *
 * Unfortunately, when testing ConnectApi methods Salesforce requires SeeAllData = true.
 * If you don't then you'll get an error: "System.UnsupportedOperationException: ConnectApi methods are not supported in data siloed tests. Please use @IsTest(SeeAllData=true)."
 */
@isTest( seeAllData = true )
private class ChatterBotPostMessageEmailHandlerTest {

    private static ChatterBotPostMessageInvocable.Request buildRequest( String authorId, String subjectId, String recordId, String emailTemplateName ) {

        ChatterBotPostMessageInvocable.Request request = new ChatterBotPostMessageInvocable.Request();

        request.authorId = authorId;
        request.subjectId = subjectId;
        request.recordId = recordId;
        request.emailTemplateName = emailTemplateName;

        return request;
    }

    @isTest( seeAllData = true )
    static void test_post_message_fail() {

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
        email.plainTextBody = null;

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( false, result.success );

    }

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
        email.plainTextBody = JSON.serialize( new List<ChatterBotPostMessageInvocable.Request>{ req } );

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
    static void test_post_messages() {

        CollaborationGroup grp = new CollaborationGroup(
            name = 'Test Group ' + DateTime.now().getTime(),
            collaborationType = 'Public'
        );

        insert grp;

        List<ChatterBotPostMessageInvocable.Request> requests = new List<ChatterBotPostMessageInvocable.Request>();

        for ( Integer i = 0; i < 50; i++ ) {
            requests.add( buildRequest(
                UserInfo.getUserId(),   // author
                grp.id,                 // subject
                UserInfo.getUserId(),   // template merge record
                'Chatter_Bot_Post_Message_Template'
            ));
        }

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Chatter Bot Post Message';
        email.plainTextBody = JSON.serialize( requests );

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();

        ChatterBotPostMessageEmailHandler handler = new ChatterBotPostMessageEmailHandler();
        Messaging.InboundEmailResult result = handler.handleInboundEmail( email, env );

        Test.stopTest();

        System.assertEquals( true, result.success );

        List<FeedItem> feedItems = new List<FeedItem>([ SELECT id, parentId, body FROM FeedItem WHERE parentId = :grp.id ]);

        System.debug( feedItems );

        System.assertEquals( requests.size(), feedItems.size() );

    }

}