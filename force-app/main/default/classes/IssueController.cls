/**
 * IssueController
 * Backs `issues` and `issueDetail`, plus the `applyToIssue` action.
 * Issue__c.Name IS the title (labeled "Issue Title" in the schema) — there's
 * no separate Title__c. There's also no AssignedTo__c or Requirements__c;
 * "assignee" is derived from an Approved Application__c, and "requirements"
 * is composed from the real fields the object does have (Technology__c,
 * Labels__c, Estimated_Hours__c, Due_Date__c, Good_First_Issue__c).
 */
public without sharing class IssueController {

    private static final Set<String> VALID_STATUSES = new Set<String>{ 'Open', 'In Progress', 'Assigned', 'Closed' };
    private static final Set<String> VALID_DIFFICULTIES = new Set<String>{ 'Beginner', 'Intermediate', 'Advanced' };

    @AuraEnabled(cacheable=true)
    public static List<IssueItem> getIssues(String searchTerm, String filterValue) {
        String term = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';

        String whereClause = 'WHERE Name LIKE :term';
        if (VALID_STATUSES.contains(filterValue)) {
            whereClause += ' AND Status__c = :filterValue';
        } else if (VALID_DIFFICULTIES.contains(filterValue)) {
            whereClause += ' AND Difficulty__c = :filterValue';
        }

        String query = 'SELECT Id, Name, Description__c, Status__c, Difficulty__c, Priority__c, ' +
            'Repository__c, Repository__r.Name, Repository__r.Project__c, Repository__r.Project__r.Name ' +
            'FROM Issue__c ' + whereClause + ' ' +
            'ORDER BY CreatedDate DESC LIMIT 100';

        List<IssueItem> results = new List<IssueItem>();
        for (Issue__c i : (List<Issue__c>) Database.query(query)) {
            results.add(toIssueItem(i));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static IssueDetailData getIssueDetail(Id issueId) {
        Issue__c i = [
            SELECT Id, Name, Description__c, Status__c, Difficulty__c, Priority__c,
                   Technology__c, Labels__c, Estimated_Hours__c, Due_Date__c, Good_First_Issue__c,
                   Repository__c, Repository__r.Name, Repository__r.Primary_Language__c,
                   Repository__r.Organization__r.Name,
                   Repository__r.Project__c, Repository__r.Project__r.Name
            FROM Issue__c
            WHERE Id = :issueId
            LIMIT 1
        ];

        IssueDetailData data = new IssueDetailData();
        data.issue = toIssueItem(i);
        data.repositoryLanguage = i.Repository__r != null ? i.Repository__r.Primary_Language__c : null;
        data.organizationName = i.Repository__r != null && i.Repository__r.Organization__r != null ? i.Repository__r.Organization__r.Name : null;
        data.organizationCategory = null;

        data.requirements = new List<String>();
        if (String.isNotBlank(i.Technology__c)) {
            data.requirements.add('Technology: ' + i.Technology__c);
        }
        if (i.Estimated_Hours__c != null) {
            data.requirements.add('Estimated effort: ' + i.Estimated_Hours__c + ' hour' + (i.Estimated_Hours__c == 1 ? '' : 's'));
        }
        if (i.Due_Date__c != null) {
            data.requirements.add('Due by ' + i.Due_Date__c.format());
        }
        if (String.isNotBlank(i.Labels__c)) {
            data.requirements.add('Labels: ' + i.Labels__c);
        }
        if (i.Good_First_Issue__c == true) {
            data.requirements.add('Marked as a good first issue');
        }

        data.skills = new List<String>();
        if (String.isNotBlank(i.Technology__c)) {
            for (Skill__c s : [SELECT Name FROM Skill__c WHERE Name = :i.Technology__c OR Category__c = :i.Technology__c LIMIT 5]) {
                data.skills.add(s.Name);
            }
        }

        List<Application__c> approved = [
            SELECT Contributor__r.Name
            FROM Application__c
            WHERE Issue__c = :issueId AND Status__c = 'Approved'
            LIMIT 1
        ];
        data.assigneeName = approved.isEmpty() ? null : approved[0].Contributor__r.Name;

        return data;
    }

    @AuraEnabled
    public static Id applyToIssue(Id issueId) {
        Id contributorId = ContributorController.getCurrentContributorId();
        if (contributorId == null) {
            throw new AuraHandledException('No Contributor record is linked to your Salesforce user (expected: Contributor__c owned by you). Ask an admin to check record ownership.');
        }

        List<Application__c> existing = [
            SELECT Id FROM Application__c
            WHERE Issue__c = :issueId AND Contributor__c = :contributorId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Application__c application = new Application__c(
            Issue__c = issueId,
            Contributor__c = contributorId,
            Status__c = 'Pending',
            Applied_On__c = Date.today(),
            Application_Source__c = 'Website'
        );
        insert application;
        return application.Id;
    }

    private static IssueItem toIssueItem(Issue__c i) {
        IssueItem item = new IssueItem();
        item.id = i.Id;
        item.issueNumber = '#' + String.valueOf(i.Id).right(4).toUpperCase();
        item.title = i.Name;
        item.summary = i.Description__c;
        item.status = i.Status__c;
        item.difficulty = i.Difficulty__c;
        item.priority = i.Priority__c;
        item.repositoryId = i.Repository__c;
        item.repositoryName = i.Repository__r != null ? i.Repository__r.Name : null;
        item.projectId = i.Repository__r != null ? i.Repository__r.Project__c : null;
        item.projectName = i.Repository__r != null && i.Repository__r.Project__r != null ? i.Repository__r.Project__r.Name : null;
        return item;
    }

    // ---------- DTOs ----------

    public class IssueItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String issueNumber;
        @AuraEnabled public String title;
        @AuraEnabled public String summary;
        @AuraEnabled public String status;
        @AuraEnabled public String difficulty;
        @AuraEnabled public String priority;
        @AuraEnabled public Id repositoryId;
        @AuraEnabled public String repositoryName;
        @AuraEnabled public Id projectId;
        @AuraEnabled public String projectName;
    }

    public class IssueDetailData {
        @AuraEnabled public IssueItem issue;
        @AuraEnabled public List<String> requirements;
        @AuraEnabled public List<String> skills;
        @AuraEnabled public String repositoryLanguage;
        @AuraEnabled public String organizationName;
        @AuraEnabled public String organizationCategory;
        @AuraEnabled public String assigneeName;
    }
}
