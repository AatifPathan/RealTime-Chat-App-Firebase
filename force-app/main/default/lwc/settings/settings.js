import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getSettings from '@salesforce/apex/SettingsController.getSettings';
import saveSettings from '@salesforce/apex/SettingsController.saveSettings';

export default class Settings extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';
    isSaving = false;
    showSavedBanner = false;

    activeTab = 'profile';
    activeTheme = 'Light';
    settings = {};

    wiredResult;

    tabs = [
        { label: 'Profile', value: 'profile' },
        { label: 'Notifications', value: 'notifications' },
        { label: 'Theme', value: 'theme' },
        { label: 'Password', value: 'password' }
    ].map((t) => ({ ...t, tabClass: t.value === 'profile' ? 'oc-tab is-active' : 'oc-tab' }));

    // Local-only, session state — no backing fields exist on Contributor__c
    // for notification preferences or theme. See REAL_SCHEMA.md.
    localPrefs = {
        notifyIssueAssignment: true,
        notifyApplicationUpdates: true,
        notifyWeeklyDigest: false,
        notifyMentions: true
    };

    @wire(getSettings)
    wiredSettings(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.hasError = false;
            this.settings = { ...data };
            this.refreshThemeCards();
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
            this.showErrorToast();
        }
    }

    themes = [];

    refreshThemeCards() {
        const swatchMap = { Light: 'oc-theme-swatch oc-swatch-light', Dark: 'oc-theme-swatch oc-swatch-dark', System: 'oc-theme-swatch oc-swatch-system' };
        this.themes = ['Light', 'Dark', 'System'].map((value) => ({
            label: value,
            value,
            cardClass: value === this.activeTheme ? 'oc-theme-option is-active' : 'oc-theme-option',
            swatchClass: swatchMap[value]
        }));
    }

    get notificationPrefs() {
        return [
            { field: 'notifyIssueAssignment', label: 'Issue assignments', description: 'Get notified when you\u2019re assigned to an issue', enabled: !!this.localPrefs.notifyIssueAssignment },
            { field: 'notifyApplicationUpdates', label: 'Application updates', description: 'Get notified when your applications change status', enabled: !!this.localPrefs.notifyApplicationUpdates },
            { field: 'notifyWeeklyDigest', label: 'Weekly digest', description: 'A weekly summary of activity across your organizations', enabled: !!this.localPrefs.notifyWeeklyDigest },
            { field: 'notifyMentions', label: 'Mentions', description: 'Get notified when someone mentions you in a comment', enabled: !!this.localPrefs.notifyMentions }
        ];
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get showProfile() { return this.activeTab === 'profile'; }
    get showNotifications() { return this.activeTab === 'notifications'; }
    get showTheme() { return this.activeTab === 'theme'; }
    get showPassword() { return this.activeTab === 'password'; }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.value;
        this.tabs = this.tabs.map((t) => ({ ...t, tabClass: t.value === this.activeTab ? 'oc-tab is-active' : 'oc-tab' }));
    }

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.settings = { ...this.settings, [field]: event.target.value };
    }

    handleToggle(event) {
        const field = event.currentTarget.dataset.field;
        this.localPrefs = { ...this.localPrefs, [field]: event.target.checked };
    }

    handleTheme(event) {
        this.activeTheme = event.currentTarget.dataset.value;
        this.refreshThemeCards();
    }

    handleSave() {
        this.isSaving = true;
        const { contributorId, email, githubUsername, linkedinProfile, bio } = this.settings;
        saveSettings({ settings: { contributorId, email, githubUsername, linkedinProfile, bio } })
            .then(() => {
                this.showSavedBanner = true;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Settings saved',
                    message: 'Your changes have been saved.',
                    variant: 'success'
                }));
                window.setTimeout(() => { this.showSavedBanner = false; }, 3000);
                return refreshApex(this.wiredResult);
            })
            .catch((error) => {
                this.showErrorToast('Couldn\u2019t save settings', this.reduceError(error));
            })
            .finally(() => {
                this.isSaving = false;
            });
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
            title: title || 'Couldn\u2019t load settings',
            message: message || this.errorMessage,
            variant: 'error'
        }));
    }
}
