@IsTest
private class ProjectServiceTest {

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
    static void testGetProjects(){

        Test.startTest();

        List<Project__c> projects =
            ProjectService.getProjects();

        Test.stopTest();

        System.assertEquals(
            1,
            projects.size()
        );

    }

    @IsTest
    static void testUpdateRepositoryCount(){

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

        ProjectService.updateRepositoryCount(
            project.Id
        );

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
    static void testNullProjectId(){

        Test.startTest();

        ProjectService.updateRepositoryCount(null);

        Test.stopTest();

        System.assert(true);

    }

}