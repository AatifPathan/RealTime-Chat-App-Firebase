import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMyProfile from '@salesforce/apex/ProfileController.getMyProfile';

export default class Profile extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';

    user = {};
    skills = [];
    badges = [];
    projects = [];
    repositories = [];

    wiredResult;

    @wire(getMyProfile)
    wiredProfile(result) {
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
        this.user = { ...data, initials: this.initials(data.name) };
        this.skills = (data.skills || []).map((s) => ({ ...s, style: `width:${s.level}%` }));
        this.badges = data.badges || [];
        this.projects = data.projects || [];
        this.repositories = data.repositories || [];
    }

    initials(name) {
        return (name || '').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get hasSkills() { return this.skills.length > 0; }
    get hasBadges() { return this.badges.length > 0; }
    get hasProjects() { return this.projects.length > 0; }
    get hasRepositories() { return this.repositories.length > 0; }

    goToSettings() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { page: 'settings' },
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
        return 'An unexpected error occurred while loading your profile.';
    }

    showErrorToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Couldn\u2019t load profile',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
