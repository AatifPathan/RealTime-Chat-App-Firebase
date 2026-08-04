import { LightningElement } from 'lwc';
import registerUser from '@salesforce/apex/SelfRegistrationController.registerUser';

export default class OcSelfRegister extends LightningElement {
    fullName = '';
    email = '';
    password = '';
    confirmPassword = '';
    githubUsername = '';

    isSubmitting = false;
    showSuccess = false;
    errorMessage = '';

    get submitLabel() {
        return this.isSubmitting ? 'Creating your account…' : 'Create Account';
    }

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = event.target.value;
    }

    handleSubmit() {
        this.errorMessage = '';

        if (!this.fullName.trim() || !this.email.trim() || !this.password) {
            this.errorMessage = 'Please fill in your name, email, and password.';
            return;
        }
        if (this.password.length < 8) {
            this.errorMessage = 'Password must be at least 8 characters.';
            return;
        }
        if (this.password !== this.confirmPassword) {
            this.errorMessage = 'Passwords don\u2019t match.';
            return;
        }

        this.isSubmitting = true;
        registerUser({
            fullName: this.fullName.trim(),
            email: this.email.trim(),
            password: this.password,
            githubUsername: this.githubUsername.trim()
        })
            .then(() => {
                this.showSuccess = true;
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'Something went wrong creating your account. Please try again.';
    }
}
