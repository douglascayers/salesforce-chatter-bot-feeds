/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/salesforce-chatter-bot-feeds
 *
 * Unfortunately, when testing ConnectApi methods Salesforce requires SeeAllData = true.
 * If you don't then you'll get an error: "System.UnsupportedOperationException: ConnectApi methods are not supported in data siloed tests. Please use @IsTest(SeeAllData=true)."
 */
@isTest( seeAllData = true )
private class ChatterBotPostMessageServiceTest {

    private static ChatterBotPostMessageInvocable.Request buildRequest( String authorId, String subjectId, String recordId, String emailTemplateName ) {

        ChatterBotPostMessageInvocable.Request request = new ChatterBotPostMessageInvocable.Request();

        request.authorId = authorId;
        request.subjectId = subjectId;
        request.recordId = recordId;
        request.emailTemplateName = emailTemplateName;

        return request;
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

        Test.startTest();

        new ChatterBotPostMessageService().processRequests( new List<ChatterBotPostMessageInvocable.Request>{ req } );

        Test.stopTest();

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

        Test.startTest();

        new ChatterBotPostMessageService().processRequests( requests );

        Test.stopTest();

        List<FeedItem> feedItems = new List<FeedItem>([ SELECT id, parentId, body FROM FeedItem WHERE parentId = :grp.id ]);

        System.debug( feedItems );

        System.assertEquals( requests.size(), feedItems.size() );

    }

    @IsTest( seeAllData = true )
    static void test_post_comment() {

        FeedItem fi = new FeedItem(
            parentId = UserInfo.getUserId(),
            body = 'Chatter Post'
        );

        insert fi;

        ChatterBotPostMessageInvocable.Request req = new ChatterBotPostMessageInvocable.Request();
        req.authorId = UserInfo.getUserId();
        req.subjectId = fi.id;
        req.recordId = UserInfo.getUserId();
        req.emailTemplateName = 'Chatter_Bot_Post_Message_Template';

        Test.startTest();

        new ChatterBotPostMessageService().processRequests( new List<ChatterBotPostMessageInvocable.Request>{ req } );

        Test.stopTest();

        FeedComment comment = [ SELECT id FROM FeedComment WHERE feedItemId = :fi.id LIMIT 1 ];

        System.debug( comment );

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

        try {

            Test.startTest();

            new ChatterBotPostMessageService().processRequests( new List<ChatterBotPostMessageInvocable.Request>{ req } );

            Test.stopTest();

        } catch ( ChatterBotPostMessageService.ChatterBotPostMessageException e ) {

            System.assert( e.getMessage().contains( 'Missing "authorId"' ) );

        }

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

        try {

            Test.startTest();

            new ChatterBotPostMessageService().processRequests( new List<ChatterBotPostMessageInvocable.Request>{ req } );

            Test.stopTest();

        } catch ( ChatterBotPostMessageService.ChatterBotPostMessageException e ) {

            System.assert( e.getMessage().contains( 'Missing "subjectId"' ) );

        }

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

        try {

            Test.startTest();

            new ChatterBotPostMessageService().processRequests( new List<ChatterBotPostMessageInvocable.Request>{ req } );

            Test.stopTest();

        } catch ( ChatterBotPostMessageService.ChatterBotPostMessageException e ) {

            System.assert( e.getMessage().contains( 'No email template found' ) );

        }

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

        try {

            Test.startTest();

            new ChatterBotPostMessageService().processRequests( new List<ChatterBotPostMessageInvocable.Request>{ req } );

            Test.stopTest();

        } catch ( ChatterBotPostMessageService.ChatterBotPostMessageException e ) {

            System.assert( e.getMessage().contains( 'One of either "message" or "emailTemplateName"' ) );

        }

    }

}