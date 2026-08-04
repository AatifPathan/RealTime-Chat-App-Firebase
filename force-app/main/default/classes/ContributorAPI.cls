@RestResource(urlMapping='/contributors/*')
global with sharing class ContributorAPI {

    @HttpGet
    global static List<Contributor__c> getContributors() {

        return ContributorService.getTopContributors();

    }

}