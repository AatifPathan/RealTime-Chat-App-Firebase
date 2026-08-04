import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getContributorProfile from '@salesforce/apex/ContributorController.getContributorProfile';

export default class ContributorProfile extends LightningElement {
    @api recordId;

    isLoading = true;
    hasError = false;
    errorMessage = '';

    contributor = {};
    contributionCount = 0;
    skills = [];
    repositories = [];
    projects = [];
    badges = [];
    timeline = [];

    wiredResult;

    @wire(getContributorProfile, { contributorId: '$recordId' })
    wiredContributor(result) {
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
        this.contributor = {
            id: data.id,
            name: data.name,
            role: data.role,
            bio: data.bio,
            reputation: data.reputation,
            initials: this.initials(data.name),
            joinedLabel: this.formatMonthYear(data.joinedDate)
        };

        this.skills = (data.skills || []).map((s) => ({ ...s, style: `width:${s.level}%` }));
        this.repositories = data.repositories || [];
        this.projects = data.projects || [];
        this.badges = data.badges || [];
        this.timeline = (data.timeline || []).map((t) => ({ ...t, meta: this.formatRelativeTime(t.timestamp) }));
        this.contributionCount = this.repositories.reduce((sum, r) => sum + (r.commits || 0), 0);
    }

    initials(name) {
        return (name || '').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
    }

    formatMonthYear(dateString) {
        if (!dateString) return '';
        const d = new Date(dateString);
        return d.toLocaleDateString(undefined, { month: 'long', year: 'numeric' });
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
    get hasSkills() { return this.skills.length > 0; }
    get hasRepositories() { return this.repositories.length > 0; }
    get hasProjects() { return this.projects.length > 0; }
    get hasBadges() { return this.badges.length > 0; }
    get hasTimeline() { return this.timeline.length > 0; }

    goToRepositoryDetail(event) {
        const recordId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'repositoryDetail', recordId },
            bubbles: true,
            composed: true
        }));
    }

    goToContributors() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'contributors' },
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
            title: 'Couldn\u2019t load contributor',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
