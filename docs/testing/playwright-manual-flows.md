# Playwright Manual Testing Flows

This document lists the manual UI flows tested via Playwright during development sessions. These can be repeated to verify functionality.

## Campaign & Attack Workflows

### 1. View Campaign Details

- Navigate to Campaigns list
- Click on a campaign to view details
- Verify campaign information displays correctly
- Verify attack list renders (stepper component)

### 2. Add Attack to Campaign

- Navigate to an existing campaign
- Click "Add Attack" button
- Select attack type (Dictionary, Mask, Hybrid, etc.)
- Fill in attack parameters:
  - Name
  - Word list selection (for dictionary attacks)
  - Mask selection (for mask attacks)
  - Rule list selection (optional)
- Submit the form
- Verify attack appears in campaign's attack list
- Verify estimated complexity displays correctly

### 3. View Attack Details

- Navigate to campaign with attacks
- Click on an attack to view details
- Verify attack configuration displays correctly

## Resource Management Workflows

### 4. Word List Upload & Processing

- Navigate to Word Lists
- Upload a new word list file
- Verify file uploads successfully
- Verify Sidekiq processes the file (line count calculated)
- Verify complexity/line count displays in list

### 5. Mask List Upload & Processing

- Navigate to Mask Lists
- Upload a new mask list file (.hcmask)
- Verify file uploads successfully
- Verify Sidekiq calculates complexity value
- Verify complexity displays in list

### 6. Rule List Upload & Processing

- Navigate to Rule Lists
- Upload a new rule list file (.rule)
- Verify file uploads successfully
- Verify Sidekiq counts lines
- Verify line count displays in list

### 7. Hash List Upload & Processing

- Navigate to Hash Lists
- Create new hash list with file
- Select hash type
- Verify file uploads successfully
- Verify hash items are created (ProcessHashListJob)
- Verify completion status shows "X / Y" format

## UI Component Verification

### 8. Attack Stepper Display

- Navigate to campaign with multiple attacks
- Verify stepper component renders correctly
- Verify attack status indicators display
- Verify error states show modal trigger for failed attacks

### 9. Bootstrap Icons

- Verify icons render throughout the application
- Check navigation icons
- Check action button icons
- Check status indicator icons

## Prerequisites for Testing

Before running these flows:

1. **Start Development Server**

   ```bash
   just dev
   ```

2. **Start Sidekiq** (for background job processing)

   ```bash
   just sidekiq
   ```

3. **Seed Data** (if needed)

   ```bash
   bin/rails db:seed
   ```

## Notes

- Word list complexity shows as "0" or "pending" until Sidekiq processes the file
- Mask list complexity is calculated from mask patterns (can be very large numbers)
- Hash list shows "importing..." until ProcessHashListJob completes
- ERB strict locals require proper magic comments: `<%# locals: (var:) -%>`
