@IsTest
private class RepositoryTriggerHandlerTest {

    @TestSetup
    static void setupData(){

        Organization__c org = new Organization__c(

            Name = 'Test Organization',
            Active__c = true

        );

        insert org;

        Project__c project = new Project__c(

            Name = 'Test Project',
            Organization__c = org.Id,
            Active__c = true

        );

        insert project;

    }

    @IsTest
    static void testAfterInsert(){

        Project__c project = [

            SELECT Id,
                   Organization__c

            FROM Project__c

            LIMIT 1

        ];

        Test.startTest();

        Repository__c repo = new Repository__c(

            Name = 'Repository One',
            Project__c = project.Id,
            Organization__c = project.Organization__c,
            Status__c = 'Active',
            Active__c = true

        );

        insert repo;

        Test.stopTest();

        project = [

            SELECT Total_Repositories__c

            FROM Project__c

            WHERE Id = :project.Id

        ];

        System.assertEquals(
            1,
            project.Total_Repositories__c
        );

    }

    @IsTest
    static void testAfterUpdate(){

        Project__c project = [

            SELECT Id,
                   Organization__c

            FROM Project__c

            LIMIT 1

        ];

        Repository__c repo = new Repository__c(

            Name = 'Repository One',
            Project__c = project.Id,
            Organization__c = project.Organization__c,
            Status__c = 'Active',
            Active__c = true

        );

        insert repo;

        Test.startTest();

        repo.Description__c = 'Updated Description';

        update repo;

        Test.stopTest();

        System.assertEquals(
            'Updated Description',
            [

                SELECT Description__c

                FROM Repository__c

                WHERE Id = :repo.Id

            ].Description__c
        );

    }

    @IsTest
    static void testAfterDelete(){

        Project__c project = [

            SELECT Id,
                   Organization__c

            FROM Project__c

            LIMIT 1

        ];

        Repository__c repo = new Repository__c(

            Name = 'Repository One',
            Project__c = project.Id,
            Organization__c = project.Organization__c,
            Status__c = 'Active',
            Active__c = true

        );

        insert repo;

        Test.startTest();

        delete repo;

        Test.stopTest();

        project = [

            SELECT Total_Repositories__c

            FROM Project__c

            WHERE Id = :project.Id

        ];

        System.assertEquals(
            0,
            project.Total_Repositories__c
        );

    }

}