public with sharing class ApplicationTriggerHandler {

    public static void afterInsert(List<Application__c> newApplications) {

        System.debug('New Application Created');

    }

    public static void afterUpdate(
        List<Application__c> newApplications,
        Map<Id, Application__c> oldMap
    ) {

        System.debug('Application Updated');

    }

}