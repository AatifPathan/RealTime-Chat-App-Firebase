/**
 * OrganizationController
 * Backs `organizations` and `organizationDetail`. Rewritten against the
 * real org schema — see REAL_SCHEMA.md for field mapping notes.
 * Repo/contributor counts are trigger-maintained rollups (Total_Repositories__c,
 * Active_Contributors__c) — read directly rather than recomputed.
 */
public without sharing class OrganizationController {

    /**
     * Lightweight id/name list used to populate Organization dropdowns on
     * the Repository and Project "create new" forms.
     */
    @AuraEnabled
    public static List<OptionItem> getOrganizationOptions() {
        List<OptionItem> options = new List<OptionItem>();
        for (Organization__c o : [SELECT Id, Name FROM Organization__c ORDER BY Name LIMIT 200]) {
            OptionItem item = new OptionItem();
            item.id = o.Id;
            item.name = o.Name;
            options.add(item);
        }
        return options;
    }

    /**
     * Creating an Organization requires being logged in (not open to
     * anonymous guests) — same rule as applying to an issue.
     */
    @AuraEnabled
    public static Id createOrganization(String name, String description, String website, String techStack) {
        if (ContributorController.getCurrentContributorId() == null) {
            throw new AuraHandledException('Please log in to add an organization.');
        }
        if (String.isBlank(name)) {
            throw new AuraHandledException('Organization name is required.');
        }

        Organization__c org = new Organization__c(
            Name = name,
            Description__c = description,
            Website__c = website,
            Technology_Stack__c = techStack
        );
        insert org;
        return org.Id;
    }

    public class OptionItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    @AuraEnabled(cacheable=true)
    public static OrgListResult getOrganizations(String searchTerm, String sortBy, Boolean sortAsc, Integer pageNumber, Integer pageSize) {
        pageNumber = pageNumber == null || pageNumber < 1 ? 1 : pageNumber;
        pageSize = pageSize == null || pageSize < 1 ? 9 : pageSize;
        Integer offset = (pageNumber - 1) * pageSize;
        String term = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';
        String direction = sortAsc == false ? 'DESC' : 'ASC';

        String query = 'SELECT Id, Name, Description__c, Technology_Stack__c, Website__c, ' +
            'Total_Repositories__c, Active_Contributors__c ' +
            'FROM Organization__c WHERE Name LIKE :term ' +
            'ORDER BY Name ' + direction + ' ' +
            'LIMIT :pageSize OFFSET :offset';

        List<Organization__c> records = Database.query(query);

        OrgListResult result = new OrgListResult();
        result.totalCount = [SELECT COUNT() FROM Organization__c WHERE Name LIKE :term];
        result.organizations = new List<OrgItem>();
        for (Organization__c o : records) {
            result.organizations.add(toOrgItem(o));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static OrgDetail getOrganizationDetail(Id organizationId) {
        Organization__c org = [
            SELECT Id, Name, Description__c, Technology_Stack__c, Website__c,
                   Total_Repositories__c, Active_Contributors__c,
                   Primary_Mentor__c, Primary_Mentor__r.Name
            FROM Organization__c
            WHERE Id = :organizationId
            LIMIT 1
        ];

        OrgDetail detail = new OrgDetail();
        detail.organization = toOrgItem(org);
        detail.mentorName = org.Primary_Mentor__c != null ? org.Primary_Mentor__r.Name : null;

        detail.repositories = new List<RepoSummary>();
        for (Repository__c r : [
            SELECT Id, Name, Primary_Language__c, Stars__c
            FROM Repository__c
            WHERE Organization__c = :organizationId
            ORDER BY Stars__c DESC NULLS LAST
            LIMIT 6
        ]) {
            RepoSummary rs = new RepoSummary();
            rs.id = r.Id;
            rs.name = r.Name;
            rs.language = r.Primary_Language__c;
            rs.stars = r.Stars__c == null ? 0 : Integer.valueOf(r.Stars__c);
            detail.repositories.add(rs);
        }

        detail.projects = new List<ProjectSummary>();
        List<Id> projectIds = new List<Id>();
        Map<Id, DashboardController.ProjectItem> progressByProject = new Map<Id, DashboardController.ProjectItem>();
        for (Project__c p : [
            SELECT Id, Name
            FROM Project__c
            WHERE Organization__c = :organizationId
            ORDER BY CreatedDate DESC
            LIMIT 6
        ]) {
            DashboardController.ProjectItem item = new DashboardController.ProjectItem();
            item.id = p.Id;
            item.name = p.Name;
            item.progress = 0;
            progressByProject.put(p.Id, item);
            projectIds.add(p.Id);
        }
        DashboardController.applyProjectProgress(progressByProject);
        for (Id pid : projectIds) {
            ProjectSummary ps = new ProjectSummary();
            ps.id = pid;
            ps.name = progressByProject.get(pid).name;
            ps.progress = progressByProject.get(pid).progress;
            detail.projects.add(ps);
        }

        // No direct Contributor__c -> Organization__c field. Derive via
        // Contribution__c on issues under this org's repositories.
        detail.contributors = new List<ContributorSummary>();
        Set<Id> contributorIds = new Set<Id>();
        for (Contribution__c con : [
            SELECT Contributor__c
            FROM Contribution__c
            WHERE Issue__r.Repository__r.Organization__c = :organizationId AND Contributor__c != null
            LIMIT 200
        ]) {
            contributorIds.add(con.Contributor__c);
        }
        if (!contributorIds.isEmpty()) {
            for (Contributor__c c : [
                SELECT Id, Name, Experience_Level__c, Current_Rank__c
                FROM Contributor__c
                WHERE Id IN :contributorIds
                ORDER BY Reputation_Score__c DESC NULLS LAST
                LIMIT 8
            ]) {
                ContributorSummary cs = new ContributorSummary();
                cs.id = c.Id;
                cs.name = c.Name;
                cs.role = (c.Experience_Level__c == null ? '' : c.Experience_Level__c) +
                    (c.Current_Rank__c == null ? '' : ' \u00B7 ' + c.Current_Rank__c);
                detail.contributors.add(cs);
            }
        }

        return detail;
    }

    private static OrgItem toOrgItem(Organization__c o) {
        OrgItem item = new OrgItem();
        item.id = o.Id;
        item.name = o.Name;
        item.description = o.Description__c;
        List<String> stack = String.isBlank(o.Technology_Stack__c)
            ? new List<String>()
            : o.Technology_Stack__c.split('[,;]\\s*');
        item.stack = stack;
        // No dedicated Category__c field — use the first listed technology
        // as a real, data-driven stand-in for the card's category line.
        item.category = stack.isEmpty() ? null : stack[0];
        item.website = o.Website__c;
        item.repoCount = o.Total_Repositories__c == null ? 0 : Integer.valueOf(o.Total_Repositories__c);
        item.contributorCount = o.Active_Contributors__c == null ? 0 : Integer.valueOf(o.Active_Contributors__c);
        return item;
    }

    // ---------- DTOs ----------

    public class OrgListResult {
        @AuraEnabled public List<OrgItem> organizations;
        @AuraEnabled public Integer totalCount;
    }

    public class OrgItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String category;
        @AuraEnabled public List<String> stack;
        @AuraEnabled public String website;
        @AuraEnabled public Integer repoCount;
        @AuraEnabled public Integer contributorCount;
    }

    public class OrgDetail {
        @AuraEnabled public OrgItem organization;
        @AuraEnabled public String mentorName;
        @AuraEnabled public List<RepoSummary> repositories;
        @AuraEnabled public List<ProjectSummary> projects;
        @AuraEnabled public List<ContributorSummary> contributors;
    }

    public class RepoSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String language;
        @AuraEnabled public Integer stars;
    }

    public class ProjectSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer progress;
    }

    public class ContributorSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
    }
}
