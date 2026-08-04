@isTest
public class TestDataFactory {

    public static Organization__c createOrganization() {

        Organization__c org = new Organization__c(
            Name = 'OpenAI Organization',
            Active__c = true,
            Technology_Stack__c = 'Java, Apex'
        );

        insert org;
        return org;
    }

    public static Project__c createProject(Id organizationId) {

        Project__c project = new Project__c(
            Name = 'OpenCore Project',
            Organization__c = organizationId,
            Active__c = true
        );

        insert project;
        return project;
    }

    public static Repository__c createRepository(
        Id organizationId,
        Id projectId
    ){

        Repository__c repo = new Repository__c(
            Name = 'OpenCore Repository',
            Organization__c = organizationId,
            Project__c = projectId,

            Active__c = true,
            Status__c = 'Active',

            Stars__c = 100,
            Forks__c = 20,
            Watchers__c = 30,
            Open_Issues__c = 5,
            Description__c = 'Repository for testing'
        );

        insert repo;
        return repo;
    }

    public static Issue__c createIssue(Id repositoryId){

        Issue__c issue = new Issue__c(
            Name = 'Bug Fix',
            Repository__c = repositoryId
        );

        insert issue;
        return issue;
    }

    public static Contributor__c createContributor(){

        Contributor__c contributor = new Contributor__c(
            Name = 'John Doe',
            Email__c = 'john@test.com'
        );

        insert contributor;
        return contributor;
    }

}