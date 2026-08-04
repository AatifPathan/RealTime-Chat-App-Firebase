public with sharing class BadgeTriggerHandler {

    public static void afterInsert(List<Badge__c> badges) {

        System.debug('Badge Awarded');

    }

    public static void afterUpdate(
        List<Badge__c> badges,
        Map<Id, Badge__c> oldMap
    ) {

        System.debug('Badge Updated');

    }

}