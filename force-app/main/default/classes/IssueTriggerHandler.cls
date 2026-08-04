public with sharing class IssueTriggerHandler {

    public static void afterInsert(List<Issue__c> newIssues){

        Set<Id> repositoryIds = new Set<Id>();

        for(Issue__c issue : newIssues){

            if(issue.Repository__c != null){

                repositoryIds.add(issue.Repository__c);

            }

        }

        for(Id repoId : repositoryIds){

            RepositoryService.updateOpenIssues(repoId);

        }

    }

    public static void afterUpdate(
        List<Issue__c> newIssues,
        Map<Id, Issue__c> oldMap
    ){

        Set<Id> repositoryIds = new Set<Id>();

        for(Issue__c issue : newIssues){

            if(issue.Repository__c != null){

                repositoryIds.add(issue.Repository__c);

            }

            Issue__c oldIssue = oldMap.get(issue.Id);

            if(oldIssue.Repository__c != null){

                repositoryIds.add(oldIssue.Repository__c);

            }

        }

        for(Id repoId : repositoryIds){

            RepositoryService.updateOpenIssues(repoId);

        }

    }

    public static void afterDelete(List<Issue__c> oldIssues){

        Set<Id> repositoryIds = new Set<Id>();

        for(Issue__c issue : oldIssues){

            if(issue.Repository__c != null){

                repositoryIds.add(issue.Repository__c);

            }

        }

        for(Id repoId : repositoryIds){

            RepositoryService.updateOpenIssues(repoId);

        }

    }

}