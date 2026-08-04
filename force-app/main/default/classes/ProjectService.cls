public with sharing class ProjectService {

    public static List<Project__c> getProjects(){

        return [

            SELECT Id,
                   Name,
                   Status__c,
                   Active__c,
                   Total_Repositories__c,
                   Organization__r.Name

            FROM Project__c

        ];

    }

    public static void updateRepositoryCount(Id projectId){

        if(projectId == null)
            return;

        Integer repoCount = [

            SELECT COUNT()

            FROM Repository__c

            WHERE Project__c = :projectId

        ];

        Project__c project = new Project__c(

            Id = projectId,
            Total_Repositories__c = repoCount

        );

        update project;

    }

}