/**
 * SettingsController
 * Backs `settings` Profile tab only. The real Contributor__c object has no
 * notification-preference or theme-preference fields, so — per "don't
 * regenerate objects" — those two tabs are local, session-only state on the
 * LWC side now (see settings.js) rather than fake-persisted here. Only the
 * fields that actually exist are read/written: Email__c, GitHub_Username__c,
 * LinkedIn_Profile__c, Bio__c.
 */
public with sharing class SettingsController {

    @AuraEnabled(cacheable=true)
    public static SettingsData getSettings() {
        Id contributorId = ContributorController.getCurrentContributorId();
        if (contributorId == null) {
            throw new AuraHandledException('No Contributor record is linked to your Salesforce user. Ask an admin to check record ownership.');
        }

        Contributor__c c = [
            SELECT Id, Name, Email__c, GitHub_Username__c, LinkedIn_Profile__c, Bio__c
            FROM Contributor__c
            WHERE Id = :contributorId
            LIMIT 1
        ];

        SettingsData data = new SettingsData();
        data.contributorId = c.Id;
        data.name = c.Name;
        data.email = c.Email__c;
        data.githubUsername = c.GitHub_Username__c;
        data.linkedinProfile = c.LinkedIn_Profile__c;
        data.bio = c.Bio__c;
        return data;
    }

    @AuraEnabled
    public static void saveSettings(SettingsData settings) {
        if (settings == null || settings.contributorId == null) {
            throw new AuraHandledException('Missing contributor reference \u2014 cannot save settings.');
        }

        Contributor__c toUpdate = new Contributor__c(
            Id = settings.contributorId,
            Email__c = settings.email,
            GitHub_Username__c = settings.githubUsername,
            LinkedIn_Profile__c = settings.linkedinProfile,
            Bio__c = settings.bio
        );
        update toUpdate;
    }

    // ---------- DTO ----------

    public class SettingsData {
        @AuraEnabled public Id contributorId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String githubUsername;
        @AuraEnabled public String linkedinProfile;
        @AuraEnabled public String bio;
    }
}
