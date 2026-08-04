import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMentorDashboard from '@salesforce/apex/MentorController.getMentorDashboard';

export default class MentorDashboard extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';

    stats = { pendingApplications: 0, activeProjects: 0, repositoriesMentored: 0, reviewsThisMonth: 0 };
    pendingApplications = [];
    projects = [];
    repositories = [];
    recentReviews = [];

    wiredResult;

    @wire(getMentorDashboard)
    wiredDashboard(result) {
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
        this.stats = data.stats || this.stats;
        this.pendingApplications = (data.pendingApplications || []).map((a) => ({
            ...a,
            initials: this.initials(a.applicantName)
        }));
        this.projects = (data.projects || []).map((p) => ({ ...p, style: `width:${p.progress}%` }));
        this.repositories = (data.repositories || []).map((r) => ({ ...r, initials: this.initials(r.name) }));
        this.recentReviews = (data.recentReviews || []).map((r) => ({ ...r, meta: this.formatRelativeTime(r.timestamp) }));
    }

    initials(name) {
        return (name || '').split(/[\s-]+/).map((p) => p[0]).join('').slice(0, 2).toUpperCase();
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
    get hasPendingApplications() { return this.pendingApplications.length > 0; }
    get hasProjects() { return this.projects.length > 0; }
    get hasRepositories() { return this.repositories.length > 0; }
    get hasRecentReviews() { return this.recentReviews.length > 0; }

    handleReviewClick(event) {
        const appId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'applicationReview', recordId: appId },
            bubbles: true,
            composed: true
        }));
    }

    goToApplications() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'applications' },
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
            title: 'Couldn\u2019t load mentor dashboard',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
