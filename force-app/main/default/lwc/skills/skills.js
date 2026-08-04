import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getSkillsForCurrentUser from '@salesforce/apex/SkillController.getSkillsForCurrentUser';

const CATEGORY_ICONS = {
    'Programming Language': '⌘',
    Salesforce: '☁',
    Database: '⛁',
    DevOps: '⚙',
    Frontend: '◍',
    Backend: '⌂',
    Other: '◆'
};

export default class Skills extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';
    skills = [];

    wiredResult;

    @wire(getSkillsForCurrentUser)
    wiredSkills(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.hasError = false;
            this.skills = data.map((s) => ({
                ...s,
                icon: CATEGORY_ICONS[s.category] || '◆',
                style: `width:${s.level}%`,
                hasProjects: (s.projects || []).length > 0
            }));
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
            this.showErrorToast();
        }
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get isEmpty() { return this.skills.length === 0; }

    loadSkills() {
        this.isLoading = true;
        this.hasError = false;
        refreshApex(this.wiredResult).finally(() => { this.isLoading = false; });
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred while loading skills.';
    }

    showErrorToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Couldn\u2019t load skills',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
