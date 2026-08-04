import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getProjectDetail from '@salesforce/apex/ProjectController.getProjectDetail';

const STATUS_CLASS = {
    Active: 'oc-badge oc-badge-blue',
    'On Hold': 'oc-badge oc-badge-amber',
    Completed: 'oc-badge oc-badge-green',
    Planning: 'oc-badge oc-badge-outline',
    Cancelled: 'oc-badge oc-badge-red'
};
const DIFF_CLASS = {
    Beginner: 'oc-badge oc-badge-green',
    Intermediate: 'oc-badge oc-badge-amber',
    Advanced: 'oc-badge oc-badge-red'
};

export default class ProjectDetail extends LightningElement {
    @api recordId;

    isLoading = true;
    hasError = false;
    errorMessage = '';

    project = {};
    description = '';
    repos = [];
    issues = [];
    maintainers = [];
    timeline = [];

    wiredResult;

    @wire(getProjectDetail, { projectId: '$recordId' })
    wiredProject(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.hasError = false;
            this.applyData(data);
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
            this.showErrorToast();
        }
    }

    applyData(data) {
        const p = data.project || {};
        this.project = {
            ...p,
            statusClass: STATUS_CLASS[p.status] || 'oc-badge',
            style: `width:${p.progress}%`
        };
        this.description = data.description;
        this.repos = data.repositories || [];
        this.issues = (data.openIssues || []).map((i) => ({ ...i, diffClass: DIFF_CLASS[i.difficulty] || 'oc-badge' }));
        this.maintainers = (data.maintainers || []).map((m) => ({ ...m, initials: this.initials(m.name) }));
        this.timeline = (data.timeline || []).map((t) => ({ ...t, meta: this.formatRelativeTime(t.timestamp) }));
    }

    initials(name) {
        return (name || '').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
    }

    formatRelativeTime(isoString) {
        if (!isoString) return '';
        const minutes = Math.floor((Date.now() - new Date(isoString).getTime()) / 60000);
        if (minutes < 60) return `${minutes} min ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours} hr ago`;
        return `${Math.floor(hours / 24)} day(s) ago`;
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get hasRepos() { return this.repos.length > 0; }
    get hasIssues() { return this.issues.length > 0; }
    get hasMaintainers() { return this.maintainers.length > 0; }
    get hasTimeline() { return this.timeline.length > 0; }

    goToRepositoryDetail(event) {
        const recordId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'repositoryDetail', recordId },
            bubbles: true,
            composed: true
        }));
    }

    handleApply() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'issues', recordId: this.recordId },
            bubbles: true,
            composed: true
        }));
    }

    goToProjects() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'projects' },
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

    showErrorToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Couldn\u2019t load project',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
