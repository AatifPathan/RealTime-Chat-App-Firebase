import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getBadgesForCurrentUser from '@salesforce/apex/BadgeController.getBadgesForCurrentUser';

export default class Badges extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';
    badges = [];

    wiredResult;

    @wire(getBadgesForCurrentUser)
    wiredBadges(result) {
        this.wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.hasError = false;
            this.badges = data.map((b) => ({
                ...b,
                cardClass: b.unlocked ? 'oc-card oc-card-pad' : 'oc-card oc-card-pad oc-lock-overlay',
                style: `width:${b.progress}%`
            }));
        } else if (error) {
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
            this.showErrorToast();
        }
    }

    get showContent() { return !this.isLoading && !this.hasError; }
    get isEmpty() { return this.badges.length === 0; }
    get unlockedCount() { return this.badges.filter((b) => b.unlocked).length; }
    get totalCount() { return this.badges.length; }
    get overallPercent() {
        return this.totalCount === 0 ? 0 : Math.round((this.unlockedCount / this.totalCount) * 100);
    }
    get overallStyle() { return `width:${this.overallPercent}%`; }

    loadBadges() {
        this.isLoading = true;
        this.hasError = false;
        refreshApex(this.wiredResult).finally(() => { this.isLoading = false; });
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred while loading badges.';
    }

    showErrorToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Couldn\u2019t load badges',
            message: this.errorMessage,
            variant: 'error'
        }));
    }
}
