public without sharing class RepositoryController {

    private static final Set<String> VALID_NEW_DIFFICULTIES = new Set<String>{ 'Beginner', 'Intermediate', 'Advanced' };
    private static final Set<String> VALID_NEW_STATUSES = new Set<String>{ 'Active', 'Archived', 'Under Maintenance' };

    /**
     * Creating a Repository requires being logged in — same rule as
     * applying to an issue.
     */
    @AuraEnabled
    public static Id createRepository(String name, Id organizationId, String primaryLanguage, String difficultyLevel, String status, String githubUrl, String description) {
        if (ContributorController.getCurrentContributorId() == null) {
            throw new AuraHandledException('Please log in to add a repository.');
        }
        if (String.isBlank(name) || organizationId == null) {
            throw new AuraHandledException('Repository name and organization are required.');
        }

        Repository__c repo = new Repository__c(
            Name = name,
            Organization__c = organizationId,
            Primary_Language__c = primaryLanguage,
            Difficulty_Level__c = VALID_NEW_DIFFICULTIES.contains(difficultyLevel) ? difficultyLevel : null,
            Status__c = VALID_NEW_STATUSES.contains(status) ? status : 'Active',
            Github_URL__c = githubUrl,
            Description__c = description
        );
        insert repo;
        return repo.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Repository__c> getRepositories() {
        return [
            SELECT
                Id,
                Name,
                Description__c,
                Stars__c,
                Forks__c,
                Open_Issues__c,
                Primary_Language__c,
                Difficulty_Level__c,
                Github_URL__c,
                Status__c
            FROM Repository__c
            ORDER BY Name
        ];
    }

    private static final Set<String> VALID_DIFFICULTIES = new Set<String>{ 'Beginner', 'Intermediate', 'Advanced' };
    private static final Set<String> VALID_STATUSES = new Set<String>{ 'Active', 'Archived', 'Under Maintenance' };
    private static final Map<String, String> SORTABLE_FIELDS = new Map<String, String>{
        'name' => 'Name',
        'stars' => 'Stars__c',
        'forks' => 'Forks__c',
        'issues' => 'Open_Issues__c'
    };

    /**
     * Powers the `repositories` LWC (search, filter, sort, pagination).
     * Added alongside getRepositories() above rather than replacing it, in
     * case anything else already calls the simple version.
     */
    @AuraEnabled(cacheable=true)
    public static RepoListResult getRepositoryList(String searchTerm, String filterValue, String sortBy, Boolean sortAsc, Integer pageNumber, Integer pageSize) {
        pageNumber = pageNumber == null || pageNumber < 1 ? 1 : pageNumber;
        pageSize = pageSize == null || pageSize < 1 ? 10 : pageSize;
        Integer offset = (pageNumber - 1) * pageSize;
        String term = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';
        String sortField = SORTABLE_FIELDS.containsKey(sortBy) ? SORTABLE_FIELDS.get(sortBy) : 'Name';
        String direction = sortAsc == false ? 'DESC' : 'ASC';

        String whereClause = 'WHERE Name LIKE :term';
        if (VALID_DIFFICULTIES.contains(filterValue)) {
            whereClause += ' AND Difficulty_Level__c = :filterValue';
        } else if (VALID_STATUSES.contains(filterValue)) {
            whereClause += ' AND Status__c = :filterValue';
        }

        String query = 'SELECT Id, Name, Organization__r.Name, Primary_Language__c, Stars__c, Forks__c, ' +
            'Open_Issues__c, Difficulty_Level__c, Status__c ' +
            'FROM Repository__c ' + whereClause + ' ' +
            'ORDER BY ' + sortField + ' ' + direction + ' ' +
            'LIMIT :pageSize OFFSET :offset';

        List<Repository__c> records = Database.query(query);
        String countQuery = 'SELECT COUNT() FROM Repository__c ' + whereClause;

        RepoListResult result = new RepoListResult();
        result.totalCount = Database.countQuery(countQuery);
        result.repositories = new List<RepoItem>();
        for (Repository__c r : records) {
            result.repositories.add(toRepoItem(r));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static RepoDetail getRepositoryDetail(Id repositoryId) {
        Repository__c r = [
            SELECT Id, Name, Organization__r.Name, Primary_Language__c, Stars__c, Forks__c, Watchers__c,
                   Open_Issues__c, Difficulty_Level__c, Status__c, Description__c, Github_URL__c,
                   Topics__c, License__c, Visibility__c, Last_Synced__c
            FROM Repository__c
            WHERE Id = :repositoryId
            LIMIT 1
        ];

        RepoDetail detail = new RepoDetail();
        detail.repository = toRepoItem(r);
        detail.description = r.Description__c;
        detail.githubUrl = r.Github_URL__c;
        // No dedicated README field on Repository__c — compose a real-data
        // summary block instead of inventing readme content.
        detail.readme = composeReadme(r);

        detail.openIssues = new List<IssueSummary>();
        for (Issue__c i : [
            SELECT Id, Name, Difficulty__c, CreatedDate
            FROM Issue__c
            WHERE Repository__c = :repositoryId AND Status__c != 'Closed'
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            IssueSummary is = new IssueSummary();
            is.id = i.Id;
            is.issueNumber = '#' + String.valueOf(i.Id).right(4).toUpperCase();
            is.title = i.Name;
            is.difficulty = i.Difficulty__c;
            is.createdDate = i.CreatedDate;
            detail.openIssues.add(is);
        }

        detail.contributors = new List<ContributorContribution>();
        Map<Id, Integer> countByContributor = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Contributor__c contributorId, COUNT(Id) cnt
            FROM Contribution__c
            WHERE Issue__r.Repository__c = :repositoryId AND Contributor__c != null
            GROUP BY Contributor__c
            ORDER BY COUNT(Id) DESC
            LIMIT 8
        ]) {
            countByContributor.put((Id) ar.get('contributorId'), (Integer) ar.get('cnt'));
        }
        if (!countByContributor.isEmpty()) {
            for (Contributor__c c : [SELECT Id, Name FROM Contributor__c WHERE Id IN :countByContributor.keySet()]) {
                ContributorContribution cc = new ContributorContribution();
                cc.id = c.Id;
                cc.name = c.Name;
                cc.contributionCount = countByContributor.get(c.Id);
                detail.contributors.add(cc);
            }
        }

        detail.activity = new List<ActivityItem>();
        for (Contribution__c con : [
            SELECT Id, Review_Status__c, Contributor__r.Name, CreatedDate
            FROM Contribution__c
            WHERE Issue__r.Repository__c = :repositoryId
            ORDER BY CreatedDate DESC
            LIMIT 5
        ]) {
            ActivityItem item = new ActivityItem();
            item.id = con.Id;
            item.text = (con.Contributor__r != null ? con.Contributor__r.Name : 'Someone') + ' \u2014 ' + con.Review_Status__c;
            item.timestamp = con.CreatedDate;
            detail.activity.add(item);
        }

        return detail;
    }

    /**
     * No bookmarking object exists in this schema. Left as a documented
     * no-op hook (same as before) — wire this to a real object if/when
     * bookmarking needs to persist.
     */
    @AuraEnabled
    public static void toggleBookmark(Id repositoryId, Id contributorId, Boolean isBookmarked) {
    }

    /**
     * Thin wrapper so the LWC can call sync + know when it's done without
     * reaching into GitHubSyncController directly by a different name.
     * Delegates entirely to your existing sync logic — nothing new here.
     */
    @AuraEnabled
    public static void syncFromGitHub(Id repositoryId) {
        GitHubSyncController.syncRepository(repositoryId);
    }

    private static String composeReadme(Repository__c r) {
        List<String> lines = new List<String>();
        if (String.isNotBlank(r.Description__c)) {
            lines.add(r.Description__c);
        }
        List<String> facts = new List<String>();
        if (String.isNotBlank(r.License__c)) {
            facts.add('License: ' + r.License__c);
        }
        if (String.isNotBlank(r.Visibility__c)) {
            facts.add('Visibility: ' + r.Visibility__c);
        }
        if (String.isNotBlank(r.Topics__c)) {
            facts.add('Topics: ' + r.Topics__c);
        }
        if (r.Last_Synced__c != null) {
            facts.add('Last synced from GitHub: ' + r.Last_Synced__c.format('MMM d, yyyy h:mm a'));
        }
        if (!facts.isEmpty()) {
            lines.add(String.join(facts, '\n'));
        }
        return lines.isEmpty() ? null : String.join(lines, '\n\n');
    }

    private static RepoItem toRepoItem(Repository__c r) {
        RepoItem item = new RepoItem();
        item.id = r.Id;
        item.name = r.Name;
        item.organizationName = r.Organization__r != null ? r.Organization__r.Name : null;
        item.language = r.Primary_Language__c;
        item.stars = r.Stars__c == null ? 0 : Integer.valueOf(r.Stars__c);
        item.forks = r.Forks__c == null ? 0 : Integer.valueOf(r.Forks__c);
        item.openIssuesCount = r.Open_Issues__c == null ? 0 : Integer.valueOf(r.Open_Issues__c);
        item.difficulty = r.Difficulty_Level__c;
        item.status = r.Status__c;
        return item;
    }

    // ---------- DTOs ----------

    public class RepoListResult {
        @AuraEnabled public List<RepoItem> repositories;
        @AuraEnabled public Integer totalCount;
    }

    public class RepoItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String organizationName;
        @AuraEnabled public String language;
        @AuraEnabled public Integer stars;
        @AuraEnabled public Integer forks;
        @AuraEnabled public Integer openIssuesCount;
        @AuraEnabled public String difficulty;
        @AuraEnabled public String status;
    }

    public class RepoDetail {
        @AuraEnabled public RepoItem repository;
        @AuraEnabled public String description;
        @AuraEnabled public String githubUrl;
        @AuraEnabled public String readme;
        @AuraEnabled public List<IssueSummary> openIssues;
        @AuraEnabled public List<ContributorContribution> contributors;
        @AuraEnabled public List<ActivityItem> activity;
    }

    public class IssueSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String issueNumber;
        @AuraEnabled public String title;
        @AuraEnabled public String difficulty;
        @AuraEnabled public Datetime createdDate;
    }

    public class ContributorContribution {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer contributionCount;
    }

    public class ActivityItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String text;
        @AuraEnabled public Datetime timestamp;
    }
}