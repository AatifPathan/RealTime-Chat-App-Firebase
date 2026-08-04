import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getIssues from '@salesforce/apex/IssueController.getIssues';
import applyToIssue from '@salesforce/apex/IssueController.applyToIssue';

const STATUS_CLASS = {
    Open: 'oc-badge oc-badge-blue',
    'In Progress': 'oc-badge oc-badge-amber',
    Assigned: 'oc-badge oc-badge-purple',
    Closed: 'oc-badge oc-badge-outline'
};
const DIFF_CLASS = {
    Beginner: 'oc-badge oc-badge-green',
    Intermediate: 'oc-badge oc-badge-amber',
    Advanced: 'oc-badge oc-badge-red'
};

export default class Issues extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';
    isApplying = false;

    searchTerm = '';
    activeFilter = 'all';
    issues = [];
    searchDebounce;

    filters = [
        { label: 'All', value: 'all' },
        { label: 'Open', value: 'Open' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Assigned', value: 'Assigned' },
        { label: 'Beginner', value: 'Beginner' },
        { label: 'Advanced', value: 'Advanced' }
    ].map((f) => ({ ...f, chipClass: f.value === 'all' ? 'oc-chip is-active' : 'oc-chip' }));

    connectedCallback() {
        this.loadIssues();
    }

    loadIssues() {
        this.isLoading = true;
        this.hasError = false;
        getIssues({ searchTerm: this.searchTerm, filterValue: this.activeFilter })
            .then((data) => {
                this.issues = (data || []).map((i) => ({
                    ...i,
                    statusClass: STATUS_CLASS[i.status] || 'oc-badge',
                    diffClass: DIFF_CLASS[i.difficulty] || 'oc-badge'
                }));
                this.hasError = false;
            })
            .catch((error) => {
                this.hasError = true;
                this.errorMessage = this.reduceError(error);
                this.showErrorToast('Couldn\u2019t load issues', this.errorMessage);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get isEmpty() { return this.issues.length === 0; }

    handleSearch(event) {
        window.clearTimeout(this.searchDebounce);
        const value = event.target.value;
        this.searchDebounce = window.setTimeout(() => {
            this.searchTerm = value;
            this.loadIssues();
        }, 300);
    }

    handleFilter(event) {
        this.activeFilter = event.target.dataset.value;
        this.filters = this.filters.map((f) => ({
            ...f,
            chipClass: f.value === this.activeFilter ? 'oc-chip is-active' : 'oc-chip'
        }));
        this.loadIssues();
    }

    handleView(event) {
        const repositoryId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'repositoryDetail', recordId: repositoryId },
            bubbles: true,
            composed: true
        }));
    }

    handleApply(event) {
        const issueId = event.currentTarget.dataset.id;
        this.isApplying = true;
        applyToIssue({ issueId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Application submitted',
                    message: 'Your application has been sent to the project mentor for review.',
                    variant: 'success'
                }));
            })
            .catch((error) => {
                this.showErrorToast('Couldn\u2019t submit application', this.reduceError(error));
            })
            .finally(() => {
                this.isApplying = false;
            });
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }

    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }
}
