// This file exports the type for the layout data
export type LayoutData = {
    user?: {
        id: string;
        email: string;
        role: string;
    };
    project?: {
        id: string;
        name: string;
    };
};
