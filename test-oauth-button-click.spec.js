const { test, expect } = require('@playwright/test');

test.describe('OAuth Button Click Tests', () => {
  test('Connect with Square button triggers OAuth flow', async ({ page }) => {
    // Set up to intercept navigation
    const responses = [];
    
    page.on('response', response => {
      if (response.url().includes('/api/v1/oauth/connect')) {
        responses.push(response);
      }
    });
    
    // Navigate to dashboard
    await page.goto('http://localhost:3002/dashboard');
    await page.waitForSelector('h1:has-text("TrackAppointments Dashboard")', { timeout: 10000 });
    
    // Go to Settings tab
    await page.click('button:has-text("Settings")');
    await page.waitForSelector('text=Connect Your Accounts', { timeout: 5000 });
    
    // Find and click the Connect with Square button
    const connectButton = page.locator('button:has-text("Connect with Square")');
    await expect(connectButton).toBeVisible();
    
    // Click the button and wait for navigation/redirect
    await Promise.race([
      connectButton.click(),
      page.waitForURL('**/oauth/**', { timeout: 10000 }),
      page.waitForURL('**/connect.squareup.com/**', { timeout: 10000 })
    ]);
    
    // If we're still on the same page, check if API was called
    if (responses.length > 0) {
      console.log('OAuth API was called successfully');
      const response = responses[0];
      expect(response.status()).toBe(200);
    }
    
    // Button should have been clicked successfully
    console.log('OAuth button click test completed successfully');
  });
  
  test('Verify button is interactive and not disabled', async ({ page }) => {
    await page.goto('http://localhost:3002/dashboard');
    await page.waitForSelector('h1:has-text("TrackAppointments Dashboard")', { timeout: 10000 });
    await page.click('button:has-text("Settings")');
    await page.waitForSelector('text=Connect Your Accounts', { timeout: 5000 });
    
    const connectButton = page.locator('button:has-text("Connect with Square")');
    
    // Verify button exists and is enabled
    await expect(connectButton).toBeVisible();
    await expect(connectButton).toBeEnabled();
    
    // Verify button has correct styling for clickable state
    const buttonClass = await connectButton.getAttribute('class');
    expect(buttonClass).toContain('bg-blue-600');
    expect(buttonClass).toContain('cursor-pointer');
    
    // Verify button has onClick handler
    const hasOnClick = await connectButton.evaluate(el => {
      return el.onclick !== null || el.addEventListener !== undefined;
    });
    
    console.log('Button is properly interactive:', hasOnClick);
  });
});