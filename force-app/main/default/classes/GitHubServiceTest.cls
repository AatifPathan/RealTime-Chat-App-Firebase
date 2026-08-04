@IsTest
private class GitHubServiceTest {

    private class GitHubMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setStatusCode(200);

            res.setHeader('Content-Type','application/json');

            res.setBody(
                '{' +
                '"description":"The library for web and native user interfaces.",' +
                '"stargazers_count":246205,' +
                '"forks_count":51156,' +
                '"open_issues_count":1252,' +
                '"subscribers_count":6613,' +
                '"language":"JavaScript",' +
                '"visibility":"public",' +
                '"created_at":"2013-05-24T16:15:54Z",' +
                '"topics":["react","javascript","frontend"],' +
                '"license":{"name":"MIT License"}' +
                '}'
            );

            return res;

        }

    }

    @TestSetup
    static void setupData() {

        Organization__c org = new Organization__c(

            Name = 'Test Org',
            Active__c = true

        );

        insert org;

        Project__c project = new Project__c(

            Name = 'Test Project',
            Organization__c = org.Id,
            Active__c = true

        );

        insert project;

        Repository__c repo = new Repository__c(

            Name = 'React',
            Organization__c = org.Id,
            Project__c = project.Id,
            Github_URL__c = 'https://github.com/react/react',
            Status__c = 'Active',
            Active__c = true

        );

        insert repo;

    }

    @IsTest
    static void testGetRepository() {

        Test.setMock(

            HttpCalloutMock.class,
            new GitHubMock()

        );

        Test.startTest();

        GitHubRepositoryDTO repo =

            GitHubService.getRepository(
                'https://github.com/react/react'
            );

        Test.stopTest();

        System.assertEquals(

            'JavaScript',
            repo.language

        );

        System.assertEquals(

            246205,
            repo.stargazers_count

        );

        System.assertEquals(

            'MIT License',
            repo.license.name

        );

    }

    @IsTest
    static void testSyncRepository() {

        Repository__c repo = [

            SELECT Id

            FROM Repository__c

            LIMIT 1

        ];

        Test.setMock(

            HttpCalloutMock.class,
            new GitHubMock()

        );

        Test.startTest();

        GitHubService.syncRepository(

            repo.Id

        );

        Test.stopTest();

        repo = [

            SELECT Description__c,
                   Stars__c,
                   Forks__c,
                   Open_Issues__c,
                   Watchers__c,
                   Primary_Language__c,
                   Visibility__c,
                   License__c,
                   Topics__c

            FROM Repository__c

            WHERE Id = :repo.Id

        ];

        System.assertEquals(

            'JavaScript',
            repo.Primary_Language__c

        );

        System.assertEquals(

            246205,
            repo.Stars__c

        );

        System.assertEquals(

            'MIT License',
            repo.License__c

        );

    }

}