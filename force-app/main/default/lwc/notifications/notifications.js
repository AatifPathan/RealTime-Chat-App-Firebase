import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getNotifications from '@salesforce/apex/NotificationController.getNotifications';

const TYPE_ICON = { blue: '◍', green: '✓', amber: '◧', purple: '★' };

export default class Notifications extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';
    isMutating = false;

    activeFilter = 'all';
    notifications = [];

    wiredResult;

    filters = [
        { label: 'All', value: 'all' },
        { label: 'Unread', value: 'unread' },
        { label: 'Read', value: 'read' }
    ].map((f) => ({ ...f, chipClass: f.value === 'all' ? 'oc-chip is-active' : 'oc-chip' }));

    @wire(getNotifications)
    wiredNotifications(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.hasError = false;
            this.notifications = data.map((n) => ({
                ...n,
                icon: TYPE_ICON[n.type] || '◍',
                meta: this.formatRelativeTime(n.timestamp)
            }));
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
            this.showErrorToast();
        }
    }

    formatRelativeTime(isoString) {
        if (!isoString) return '';
        const minutes = Math.floor((Date.now() - new Date(isoString).getTime()) / 60000);
        if (minutes < 1) return 'just now';
        if (minutes < 60) return `${minutes} min ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours} hr ago`;
        return `${Math.floor(hours / 24)} day(s) ago`;
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get unreadCount() { return this.notifications.filter((n) => n.unread).length; }

    get filteredNotifications() {
        return this.notifications
            .filter((n) => {
                if (this.activeFilter === 'unread') return n.unread;
                if (this.activeFilter === 'read') return !n.unread;
                return true;
            })
            .map((n) => ({
                ...n,
                rowClass: n.unread ? 'oc-notif-row is-unread' : 'oc-notif-row',
                iconWrapClass: `oc-notif-icon-wrap type-${n.type}`
            }));
    }

    get isEmpty() { return this.filteredNotifications.length === 0; }

    handleFilter(event) {
        this.activeFilter = event.target.dataset.value;
        this.filters = this.filters.map((f) => ({
            ...f,
            chipClass: f.value === this.activeFilter ? 'oc-chip is-active' : 'oc-chip'
        }));
    }

    handleRead(event) {
        const id = event.currentTarget.dataset.id;
        const notification = this.notifications.find((n) => n.id === id);
        if (!notification || !notification.unread) return;

        // Local-only: there's no field on any real object to persist
        // read/unread state to (see REAL_SCHEMA.md). Resets on reload.
        this.notifications = this.notifications.map((n) => (n.id === id ? { ...n, unread: false } : n));
    }

    handleMarkAllRead() {
        this.notifications = this.notifications.map((n) => ({ ...n, unread: false }));
    }

    handleRetry() {
        this.isLoading = true;
        this.hasError = false;
        refreshApex(this.wiredResult).finally(() => { this.isLoading = false; });
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }

    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title || 'Couldn\u2019t load notifications',
            message: message || this.errorMessage,
            variant: 'error'
        }));
    }
}
