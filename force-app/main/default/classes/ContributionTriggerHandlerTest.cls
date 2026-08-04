@IsTest
private class ContributionTriggerHandlerTest {

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
            Name = 'Test Repository',
            Organization__c = org.Id,
            Project__c = project.Id,
            Status__c = 'Active',
            Active__c = true
        );
        insert repo;

        Issue__c issue = new Issue__c(
            Name = 'Bug Fix',
            Repository__c = repo.Id,
            Status__c = 'Open'
        );
        insert issue;

        Contributor__c contributor = new Contributor__c(
            Name = 'John Doe',
            Email__c = 'john@test.com',
            Reputation_Score__c = 0,
            Total_Contributions__c = 0
        );
        insert contributor;
    }

    @IsTest
    static void testAfterInsert() {

        Issue__c issue = [
            SELECT Id
            FROM Issue__c
            LIMIT 1
        ];

        Contributor__c contributor = [
            SELECT Id
            FROM Contributor__c
            LIMIT 1
        ];

        Test.startTest();

        Contribution__c contribution = new Contribution__c(
            Contributor__c = contributor.Id,
            Issue__c = issue.Id,
            Review_Status__c = 'Approved',
            Pull_Request_URL__c = 'https://github.com/react/react/pull/1'
        );

        insert contribution;

        Test.stopTest();

        contributor = [
            SELECT Reputation_Score__c,
                   Total_Contributions__c
            FROM Contributor__c
            WHERE Id = :contributor.Id
        ];

        System.assertEquals(20, contributor.Reputation_Score__c);
        System.assertEquals(1, contributor.Total_Contributions__c);

        List<Badge__c> badges = [
            SELECT Id
            FROM Badge__c
            WHERE Contributor__c = :contributor.Id
        ];

        System.assertEquals(1, badges.size());
    }

    @IsTest
    static void testAfterUpdate() {

        Issue__c issue = [
            SELECT Id
            FROM Issue__c
            LIMIT 1
        ];

        Contributor__c contributor = [
            SELECT Id
            FROM Contributor__c
            LIMIT 1
        ];

        Contribution__c contribution = new Contribution__c(
            Contributor__c = contributor.Id,
            Issue__c = issue.Id,
            Review_Status__c = 'Submitted',
            Pull_Request_URL__c = 'https://github.com/react/react/pull/2'
        );

        insert contribution;

        Test.startTest();

        contribution.Review_Status__c = 'Merged';

        update contribution;

        Test.stopTest();

        contributor = [
            SELECT Reputation_Score__c,
                   Total_Contributions__c
            FROM Contributor__c
            WHERE Id = :contributor.Id
        ];

        System.assertEquals(52, contributor.Reputation_Score__c);
        System.assertEquals(2, contributor.Total_Contributions__c);
    }

}