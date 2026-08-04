/**
 * NotificationController
 * Backs `notifications` and the unread-dot in openCoreApp's header. There's
 * no Notification__c object in this schema (see REAL_SCHEMA.md), so this
 * synthesizes a real, non-fabricated feed from three genuine signals for
 * the running user's Contributor__c:
 *   1. Applications reviewed in the last 14 days (approved/rejected)
 *   2. Badges awarded in the last 14 days
 *   3. Contributions reviewed in the last 14 days
 * There's no field to persist read/unread state, so "unread" here just
 * means "happened in the last 48 hours" — a reasonable proxy, not real
 * tracked state. markAsRead/markAllAsRead only update client-side state
 * (see notifications.js) since there's nothing to write back to.
 */
public with sharing class NotificationController {

    @AuraEnabled(cacheable=true)
    public static List<NotificationItem> getNotifications() {
        Id contributorId = ContributorController.getCurrentContributorId();
        List<NotificationItem> results = new List<NotificationItem>();
        if (contributorId == null) {
            return results;
        }

        for (Application__c a : [
            SELECT Id, Status__c, Issue__r.Name, Reviewed_On__c, LastModifiedDate
            FROM Application__c
            WHERE Contributor__c = :contributorId AND Status__c IN ('Approved', 'Rejected') AND Reviewed_On__c = LAST_N_DAYS:14
            ORDER BY LastModifiedDate DESC
            LIMIT 15
        ]) {
            NotificationItem item = new NotificationItem();
            item.id = 'app-' + a.Id;
            item.title = a.Status__c == 'Approved' ? 'Your application was approved' : 'Your application was not approved this time';
            item.description = a.Issue__r != null ? ('"' + a.Issue__r.Name + '"') : null;
            item.type = a.Status__c == 'Approved' ? 'green' : 'red';
            item.timestamp = a.LastModifiedDate;
            item.unread = isRecent(a.LastModifiedDate);
            results.add(item);
        }

        for (Badge__c b : [
            SELECT Id, Badge_Type__c, Awarded_Date__c, CreatedDate
            FROM Badge__c
            WHERE Contributor__c = :contributorId AND Awarded_Date__c = LAST_N_DAYS:14
            ORDER BY CreatedDate DESC
            LIMIT 15
        ]) {
            NotificationItem item = new NotificationItem();
            item.id = 'badge-' + b.Id;
            item.title = 'You earned a new badge';
            item.description = b.Badge_Type__c;
            item.type = 'purple';
            item.timestamp = b.CreatedDate;
            item.unread = isRecent(b.CreatedDate);
            results.add(item);
        }

        for (Contribution__c c : [
            SELECT Id, Review_Status__c, Issue__r.Name, LastModifiedDate
            FROM Contribution__c
            WHERE Contributor__c = :contributorId AND Review_Status__c != null AND LastModifiedDate = LAST_N_DAYS:14
            ORDER BY LastModifiedDate DESC
            LIMIT 15
        ]) {
            NotificationItem item = new NotificationItem();
            item.id = 'con-' + c.Id;
            item.title = 'Your contribution was ' + c.Review_Status__c.toLowerCase();
            item.description = c.Issue__r != null ? ('"' + c.Issue__r.Name + '"') : null;
            item.type = 'blue';
            item.timestamp = c.LastModifiedDate;
            item.unread = isRecent(c.LastModifiedDate);
            results.add(item);
        }

        // NotificationItem doesn't implement Comparable, so sort manually
        // by timestamp instead of calling List.sort().
        return sortByTimestampDesc(results);
    }

    private static Boolean isRecent(Datetime dt) {
        return dt != null && dt.addHours(48) > Datetime.now();
    }

    private static List<NotificationItem> sortByTimestampDesc(List<NotificationItem> items) {
        List<NotificationItem> sorted = items.clone();
        for (Integer i = 1; i < sorted.size(); i++) {
            NotificationItem current = sorted[i];
            Integer j = i - 1;
            while (j >= 0 && sorted[j].timestamp < current.timestamp) {
                sorted[j + 1] = sorted[j];
                j--;
            }
            sorted[j + 1] = current;
        }
        return sorted;
    }

    // ---------- DTO ----------

    public class NotificationItem {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean unread;
        @AuraEnabled public Datetime timestamp;
    }
}
