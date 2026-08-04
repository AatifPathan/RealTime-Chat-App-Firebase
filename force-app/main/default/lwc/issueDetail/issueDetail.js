import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getIssueDetail from '@salesforce/apex/IssueController.getIssueDetail';
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

export default class IssueDetail extends LightningElement {
    @api recordId;

    isLoading = true;
    hasError = false;
    errorMessage = '';
    isApplying = false;

    issue = {};
    requirements = [];
    skills = [];
    repositoryLanguage = '';
    organizationName = '';
    organizationCategory = '';
    repoInitials = '';

    wiredResult;

    @wire(getIssueDetail, { issueId: '$recordId' })
    wiredIssue(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.hasError = false;
            this.applyData(data);
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
            this.showErrorToast('Couldn\u2019t load issue', this.errorMessage);
        }
    }

    applyData(data) {
        const i = data.issue || {};
        this.issue = {
            ...i,
            statusClass: STATUS_CLASS[i.status] || 'oc-badge',
            diffClass: DIFF_CLASS[i.difficulty] || 'oc-badge'
        };
        this.requirements = data.requirements || [];
        this.skills = data.skills || [];
        this.repositoryLanguage = data.repositoryLanguage;
        this.organizationName = data.organizationName;
        this.organizationCategory = data.organizationCategory;
        this.repoInitials = this.initials(i.repositoryName);
    }

    initials(name) {
        return (name || '').split('-').map((p) => p[0]).join('').slice(0, 2).toUpperCase();
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get hasRequirements() { return this.requirements.length > 0; }
    get hasSkills() { return this.skills.length > 0; }

    handleViewRepo() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'repositoryDetail', recordId: this.issue.repositoryId },
            bubbles: true,
            composed: true
        }));
    }

    handleApply() {
        this.isApplying = true;
        applyToIssue({ issueId: this.recordId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Application submitted',
                    message: 'Your application has been sent to the project mentor for review.',
                    variant: 'success'
                }));
                this.dispatchEvent(new CustomEvent('navigate', {
                    detail: { page: 'applications' },
                    bubbles: true,
                    composed: true
                }));
            })
            .catch((error) => {
                this.showErrorToast('Couldn\u2019t submit application', this.reduceError(error));
            })
            .finally(() => {
                this.isApplying = false;
            });
    }

    goToIssues() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'issues' },
            bubbles: true,
            composed: true
        }));
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
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }
}
