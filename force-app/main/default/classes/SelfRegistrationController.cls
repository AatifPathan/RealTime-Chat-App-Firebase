/**
 * SelfRegistrationController
 * Backs the `selfRegister` public sign-up page. Creates a real Experience
 * Cloud login (via Site.createExternalUser), fetches the person's public
 * GitHub profile, and creates a Contributor__c record owned by the new
 * user — so ContributorController.getCurrentContributorId() (OwnerId-based)
 * picks it up correctly the moment they log in.
 *
 * `without sharing` is required: this runs as the Guest User, before the
 * person has any Salesforce access at all, and needs elevated access to
 * create the User/Contributor__c records.
 *
 * ---- ONE-TIME SETUP REQUIRED BEFORE THIS WORKS (see chat instructions) ----
 * Edit the two constants below to match your org:
 *   MEMBER_PROFILE_NAME  -> the exact Profile Name shown when you enabled
 *                            Self-Registration in Digital Experiences >
 *                            Administration > Login & Registration.
 *   COMMUNITY_ACCOUNT_NAME -> the exact Name of the Account record you
 *                            create for community members to belong to.
 */
public without sharing class SelfRegistrationController {

    private static final String MEMBER_PROFILE_NAME = 'OpenCore Member';
    private static final String COMMUNITY_ACCOUNT_NAME = 'OpenCore Community';

    @AuraEnabled
    public static Id registerUser(String fullName, String email, String password, String githubUsername) {
        fullName = fullName == null ? '' : fullName.trim();
        email = email == null ? '' : email.trim();

        if (String.isBlank(fullName) || String.isBlank(email) || String.isBlank(password)) {
            throw new AuraHandledException('Please fill in your name, email, and password.');
        }

        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :MEMBER_PROFILE_NAME LIMIT 1];
        if (profiles.isEmpty()) {
            throw new AuraHandledException('Sign-up isn\u2019t configured yet \u2014 the site administrator needs to set MEMBER_PROFILE_NAME in SelfRegistrationController.');
        }

        List<Account> accounts = [SELECT Id FROM Account WHERE Name = :COMMUNITY_ACCOUNT_NAME LIMIT 1];
        if (accounts.isEmpty()) {
            throw new AuraHandledException('Sign-up isn\u2019t configured yet \u2014 the site administrator needs to create the "' + COMMUNITY_ACCOUNT_NAME + '" Account record.');
        }

        // Pull real public GitHub data before creating anything — if this
        // fails or the username doesn't exist, registration still proceeds
        // with blank profile fields (see GitHubProfileService).
        GitHubProfileService.GitHubProfile githubProfile = GitHubProfileService.fetchProfile(githubUsername);

        List<String> nameParts = fullName.split(' ', 2);
        String firstName = nameParts.size() > 1 ? nameParts[0] : null;
        String lastName = nameParts.size() > 1 ? nameParts[1] : fullName;

        User newUser = new User();
        newUser.FirstName = firstName;
        newUser.LastName = lastName;
        newUser.Email = email;
        newUser.Username = email;
        newUser.Alias = (fullName.replaceAll('[^a-zA-Z]', '').length() > 8)
            ? fullName.replaceAll('[^a-zA-Z]', '').substring(0, 8)
            : (fullName.replaceAll('[^a-zA-Z]', '').length() > 0 ? fullName.replaceAll('[^a-zA-Z]', '') : 'user');
        newUser.CommunityNickname = (email.length() > 40) ? email.substring(0, 40) : email;
        newUser.ProfileId = profiles[0].Id;
        newUser.TimeZoneSidKey = 'America/Los_Angeles';
        newUser.LocaleSidKey = 'en_US';
        newUser.EmailEncodingKey = 'UTF-8';
        newUser.LanguageLocaleKey = 'en_US';

        Id newUserId;
        try {
            newUserId = Site.createExternalUser(newUser, accounts[0].Id, password, true);
        } catch (Exception e) {
            throw new AuraHandledException('Couldn\u2019t create your account: ' + e.getMessage());
        }

        if (newUserId == null) {
            throw new AuraHandledException('Couldn\u2019t create your account. That email may already be registered \u2014 try logging in instead, or use a different email.');
        }

        Contributor__c contributor = new Contributor__c();
        contributor.Name = String.isNotBlank(githubProfile.name) ? githubProfile.name : fullName;
        contributor.Email__c = email;
        contributor.GitHub_Username__c = githubUsername;
        contributor.GitHub_Profile_URL__c = githubProfile.profileUrl;
        contributor.Profile_Image_URL__c = githubProfile.avatarUrl;
        contributor.Bio__c = githubProfile.bio;
        contributor.OwnerId = newUserId;
        insert contributor;

        return newUserId;
    }
}
