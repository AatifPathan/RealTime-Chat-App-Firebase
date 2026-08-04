public with sharing class GitHubSyncController {

    @AuraEnabled
    public static void syncRepository(Id repositoryId){

        GitHubService.syncRepository(repositoryId);

    }

}