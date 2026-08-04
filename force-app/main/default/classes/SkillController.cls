/**
 * SkillController
 * Backs `skills`. Contributor_Skill__c.Proficiency_Level__c is a picklist,
 * not a 0-100 number — mapped via ContributorController.proficiencyToPercent
 * for the existing progress-bar UI. "Used in N projects" has no direct
 * backing field; for Programming Language skills it's derived from
 * Repository__c.Primary_Language__c matches (a repo's language really does
 * mean that project uses that language). Other skill categories have no
 * reliable real link to a project, so they show 0 rather than a guess.
 */
public without sharing class SkillController {

    @AuraEnabled(cacheable=true)
    public static List<SkillItem> getSkillsForCurrentUser() {
        Id contributorId = ContributorController.getCurrentContributorId();

        Map<Id, Integer> levelBySkill = new Map<Id, Integer>();
        if (contributorId != null) {
            for (Contributor_Skill__c cs : [
                SELECT Skill__c, Proficiency_Level__c
                FROM Contributor_Skill__c
                WHERE Contributor__c = :contributorId
            ]) {
                levelBySkill.put(cs.Skill__c, ContributorController.proficiencyToPercent(cs.Proficiency_Level__c));
            }
        }

        List<Skill__c> skills = [SELECT Id, Name, Category__c FROM Skill__c WHERE Active__c = true ORDER BY Category__c, Name LIMIT 100];

        Map<String, Set<String>> projectNamesByLanguage = new Map<String, Set<String>>();
        for (Repository__c r : [
            SELECT Primary_Language__c, Project__r.Name
            FROM Repository__c
            WHERE Primary_Language__c != null AND Project__c != null
            LIMIT 200
        ]) {
            if (!projectNamesByLanguage.containsKey(r.Primary_Language__c)) {
                projectNamesByLanguage.put(r.Primary_Language__c, new Set<String>());
            }
            projectNamesByLanguage.get(r.Primary_Language__c).add(r.Project__r.Name);
        }

        List<SkillItem> results = new List<SkillItem>();
        for (Skill__c s : skills) {
            SkillItem item = new SkillItem();
            item.id = s.Id;
            item.name = s.Name;
            item.category = s.Category__c;
            item.level = levelBySkill.containsKey(s.Id) ? levelBySkill.get(s.Id) : 0;
            Set<String> projectNames = projectNamesByLanguage.containsKey(s.Name) ? projectNamesByLanguage.get(s.Name) : new Set<String>();
            item.projects = new List<String>(projectNames);
            item.projectCount = item.projects.size();
            results.add(item);
        }
        return results;
    }

    // ---------- DTOs ----------

    public class SkillItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String category;
        @AuraEnabled public Integer level;
        @AuraEnabled public List<String> projects;
        @AuraEnabled public Integer projectCount;
    }
}
