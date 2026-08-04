/**
 * GitHubProfileService
 * Fetches public profile data for a GitHub username (name, bio, avatar,
 * profile URL) using the public GitHub Users API. Follows the same callout
 * pattern as the existing GitHubService.getRepository(), reusing the same
 * api.github.com endpoint (already authorized as a Remote Site Setting in
 * this org for GitHubService to work).
 *
 * Used by SelfRegistrationController to pre-fill a new Contributor__c
 * record's Bio__c / Profile_Image_URL__c / GitHub_Profile_URL__c at sign-up.
 */
public with sharing class GitHubProfileService {

    private static final String BASE_URL = 'https://api.github.com';

    public class GitHubProfile {
        public String name;
        public String bio;
        public String avatarUrl;
        public String profileUrl;
        public Boolean found = false;
    }

    public static GitHubProfile fetchProfile(String githubUsername) {
        GitHubProfile profile = new GitHubProfile();
        if (String.isBlank(githubUsername)) {
            return profile;
        }

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + '/users/' + EncodingUtil.urlEncode(githubUsername, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('User-Agent', 'Salesforce');
            req.setHeader('Accept', 'application/vnd.github+json');
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                profile.name = (String) body.get('name');
                profile.bio = (String) body.get('bio');
                profile.avatarUrl = (String) body.get('avatar_url');
                profile.profileUrl = (String) body.get('html_url');
                profile.found = true;
            }
            // Non-200 (e.g. 404 for a username that doesn't exist) is not
            // treated as an error — registration should still succeed with
            // blank profile fields the person can fill in later.
        } catch (Exception e) {
            // Swallow callout failures (timeout, DNS, etc.) for the same
            // reason — a GitHub outage should never block someone signing up.
        }
        return profile;
    }
}
