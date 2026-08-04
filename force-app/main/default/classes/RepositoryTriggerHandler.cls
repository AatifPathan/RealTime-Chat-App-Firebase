public with sharing class RepositoryTriggerHandler {

    public static void afterInsert(List<Repository__c> repositories) {

        updateStatistics(repositories);

    }

    public static void afterUpdate(
        List<Repository__c> repositories,
        Map<Id, Repository__c> oldMap
    ) {

        Set<Repository__c> reposToUpdate = new Set<Repository__c>();

        reposToUpdate.addAll(repositories);
        reposToUpdate.addAll(oldMap.values());

        updateStatistics(new List<Repository__c>(reposToUpdate));

    }

    public static void afterDelete(List<Repository__c> repositories){

        updateStatistics(repositories);

    }

    private static void updateStatistics(List<Repository__c> repositories){

        Set<Id> projectIds = new Set<Id>();
        Set<Id> organizationIds = new Set<Id>();

        for(Repository__c repo : repositories){

            if(repo.Project__c != null){

                projectIds.add(repo.Project__c);

            }

            if(repo.Organization__c != null){

                organizationIds.add(repo.Organization__c);

            }

        }

        for(Id projectId : projectIds){

            ProjectService.updateRepositoryCount(projectId);

        }

        for(Id organizationId : organizationIds){

            OrganizationService.updateRepositoryCount(organizationId);

        }

    }

}