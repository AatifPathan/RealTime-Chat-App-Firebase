import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getApplications from '@salesforce/apex/ApplicationController.getApplications';

const STATUS_CLASS = {
    Pending: 'oc-badge oc-badge-amber',
    Approved: 'oc-badge oc-badge-green',
    Rejected: 'oc-badge oc-badge-red',
    Withdrawn: 'oc-badge oc-badge-outline'
};

export default class Applications extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';

    searchTerm = '';
    activeFilter = 'all';
    applications = [];
    searchDebounce;

    filters = [
        { label: 'All', value: 'all' },
        { label: 'Pending', value: 'Pending' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Withdrawn', value: 'Withdrawn' }
    ].map((f) => ({ ...f, chipClass: f.value === 'all' ? 'oc-chip is-active' : 'oc-chip' }));

    connectedCallback() {
        this.loadApplications();
    }

    loadApplications() {
        this.isLoading = true;
        this.hasError = false;
        getApplications({ searchTerm: this.searchTerm, statusFilter: this.activeFilter })
            .then((data) => {
                this.applications = (data || []).map((a) => ({
                    ...a,
                    initials: this.initials(a.applicantName),
                    statusClass: STATUS_CLASS[a.status] || 'oc-badge',
                    appliedDateLabel: this.formatDate(a.appliedDate)
                }));
                this.hasError = false;
            })
            .catch((error) => {
                this.hasError = true;
                this.errorMessage = this.reduceError(error);
                this.showErrorToast();
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    initials(name) {
        return (name || '').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
    }

    formatDate(dateString) {
        if (!dateString) return '';
        return new Date(dateString).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get isEmpty() { return this.applications.length === 0; }
    get totalCount() { return this.applications.length; }

    handleSearch(event) {
        window.clearTimeout(this.searchDebounce);
        const value = event.target.value;
        this.searchDebounce = window.setTimeout(() => {
            this.searchTerm = value;
            this.loadApplications();
        }, 300);
    }

    handleFilter(event) {
        this.activeFilter = event.target.dataset.value;
        this.filters = this.filters.map((f) => ({
            ...f,
            chipClass: f.value === this.activeFilter ? 'oc-chip is-active' : 'oc-chip'
        }));
        this.loadApplications();
    }

    handleRowClick(event) {
        const appId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'applicationReview', recordId: appId },
            bubbles: true,
            composed: true
        }));
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred while loading applications.';
    }

    showErrorToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Couldn\u2019t load applications',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
