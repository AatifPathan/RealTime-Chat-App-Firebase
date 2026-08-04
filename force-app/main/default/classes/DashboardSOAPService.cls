global with sharing class DashboardSOAPService {

    webService static Integer totalRepositories() {
        return [SELECT COUNT() FROM Repository__c];
    }

    webService static Integer totalProjects() {
        return [SELECT COUNT() FROM Project__c];
    }

    webService static Integer totalContributors() {
        return [SELECT COUNT() FROM Contributor__c];
    }

    webService static Integer totalIssues() {
        return [SELECT COUNT() FROM Issue__c];
    }

}