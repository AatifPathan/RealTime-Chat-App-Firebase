@IsTest
private class OrganizationServiceTest {

    @TestSetup
    static void setupData(){

        Organization__c org = new Organization__c(

            Name = 'Test Organization',
            Active__c = true

        );

        insert org;

    }

    @IsTest
    static void testGetOrganizations(){

        Test.startTest();

        List<Organization__c> organizations =
            OrganizationService.getOrganizations();

        Test.stopTest();

        System.assertEquals(
            1,
            organizations.size()
        );

    }

    @IsTest
    static void testUpdateRepositoryCount(){

        Organization__c org = [

            SELECT Id

            FROM Organization__c

            LIMIT 1

        ];

        Project__c project = new Project__c(

            Name = 'Test Project',
            Organization__c = org.Id,
            Active__c = true

        );

        insert project;

        Repository__c repo = new Repository__c(

            Name = 'Repository One',
            Organization__c = org.Id,
            Project__c = project.Id,
            Status__c = 'Active',
            Active__c = true

        );

        insert repo;

        Test.startTest();

        OrganizationService.updateRepositoryCount(org.Id);

        Test.stopTest();

        org = [

            SELECT Total_Repositories__c

            FROM Organization__c

            WHERE Id = :org.Id

        ];

        System.assertEquals(
            1,
            org.Total_Repositories__c
        );

    }

    @IsTest
    static void testUpdateActiveContributors(){

        Organization__c org = [

            SELECT Id

            FROM Organization__c

            LIMIT 1

        ];

        Test.startTest();

        OrganizationService.updateActiveContributors(org.Id);

        Test.stopTest();

        org = [

            SELECT Active_Contributors__c

            FROM Organization__c

            WHERE Id = :org.Id

        ];

        System.assertEquals(
            0,
            org.Active_Contributors__c
        );

    }

}