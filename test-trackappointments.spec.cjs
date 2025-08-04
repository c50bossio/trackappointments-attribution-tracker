const { test, expect } = require('@playwright/test');

test.describe('TrackAppointments Platform Tests', () => {
  
  test('Frontend loads and displays correct branding', async ({ page }) => {
    // Navigate to the frontend
    await page.goto('http://localhost:3002');
    
    // Wait for the page to load completely
    await page.waitForLoadState('networkidle');
    
    // Check that loading screen shows TrackAppointments
    const loadingText = page.locator('text=Loading TrackAppointments...');
    
    // Wait for loading to complete and main content to appear
    await page.waitForSelector('h1:has-text("TrackAppointments")', { timeout: 10000 });
    
    // Verify main heading shows TrackAppointments
    await expect(page.locator('h1')).toContainText('TrackAppointments');
    
    // Verify the logo shows "TA" instead of "BB"
    await expect(page.locator('span.text-white:has-text("TA")')).toBeVisible();
    
    // Verify page title and main sections
    await expect(page.locator('h2:has-text("Attribution Tracking Platform")')).toBeVisible();
    
    // Check for key features
    await expect(page.locator('text=Advanced Attribution Models')).toBeVisible();
    await expect(page.locator('text=Privacy-Compliant Design')).toBeVisible();
    await expect(page.locator('text=Real-Time Analytics')).toBeVisible();
    
    // Verify footer shows TrackAppointments
    await expect(page.locator('text=TrackAppointments Attribution Tracker')).toBeVisible();
  });

  test('Backend API health check works', async ({ request }) => {
    // Test backend health endpoint
    const healthResponse = await request.get('http://localhost:8002/api/health');
    expect(healthResponse.ok()).toBeTruthy();
    
    const healthData = await healthResponse.json();
    expect(healthData.status).toBe('healthy');
    expect(healthData.service).toBe('bookingbridge-api');
    expect(healthData.components.database.status).toBe('healthy');
    expect(healthData.components.redis.status).toBe('healthy');
  });

  test('Dashboard API returns data', async ({ request }) => {
    // Test dashboard analytics endpoint
    const dashboardResponse = await request.get('http://localhost:8002/api/v1/analytics/dashboard');
    expect(dashboardResponse.ok()).toBeTruthy();
    
    const dashboardData = await dashboardResponse.json();
    expect(dashboardData).toHaveProperty('total_interactions');
    expect(dashboardData).toHaveProperty('conversion_rate');
    expect(dashboardData).toHaveProperty('attribution_accuracy');
    expect(dashboardData).toHaveProperty('recovered_revenue');
    
    // Verify data types and format
    expect(typeof dashboardData.total_interactions).toBe('number');
    expect(dashboardData.conversion_rate).toMatch(/\d+\.\d+%/);
    expect(dashboardData.attribution_accuracy).toMatch(/\d+\.\d+%/);
    expect(dashboardData.recovered_revenue).toMatch(/\$[\d,]+/);
  });

  test('Frontend displays dashboard data correctly', async ({ page }) => {
    await page.goto('http://localhost:3002');
    
    // Wait for dashboard data to load
    await page.waitForSelector('[class*="bg-blue-50"]', { timeout: 15000 });
    
    // Check that dashboard metrics are displayed
    await expect(page.locator('h3:has-text("Total Interactions")')).toBeVisible();
    await expect(page.locator('h3:has-text("Conversion Rate")')).toBeVisible();
    await expect(page.locator('h3:has-text("Attribution Accuracy")')).toBeVisible();
    await expect(page.locator('h3:has-text("Recovered Revenue")')).toBeVisible();
    
    // Verify that actual data is displayed (not just placeholders)
    const totalInteractions = page.locator('.bg-blue-50 p.text-2xl');
    await expect(totalInteractions).toContainText(/\d/);
    
    const conversionRate = page.locator('.bg-green-50 p.text-2xl');
    await expect(conversionRate).toContainText('%');
    
    const attributionAccuracy = page.locator('.bg-purple-50 p.text-2xl');
    await expect(attributionAccuracy).toContainText('%');
    
    const recoveredRevenue = page.locator('.bg-yellow-50 p.text-2xl');
    await expect(recoveredRevenue).toContainText('$');
  });

  test('System status shows operational', async ({ page }) => {
    await page.goto('http://localhost:3002');
    
    // Wait for system status section
    await page.waitForSelector('text=System Status', { timeout: 10000 });
    
    // Check that all systems show as operational
    await expect(page.locator('text=API Services')).toBeVisible();
    await expect(page.locator('text=Attribution Engine')).toBeVisible();
    await expect(page.locator('text=Data Processing')).toBeVisible();
    
    // Verify operational status indicators
    const operationalTexts = page.locator('span:has-text("Operational")');
    await expect(operationalTexts).toHaveCount(3);
    
    // Check for green status indicators
    const greenDots = page.locator('div.w-3.h-3.bg-green-500.rounded-full');
    await expect(greenDots).toHaveCount(3);
  });

  test('Health status indicator works', async ({ page }) => {
    await page.goto('http://localhost:3002');
    
    // Wait for health status to load
    await page.waitForSelector('[class*="bg-green-100"]', { timeout: 10000 });
    
    // Check that health status shows healthy
    const healthStatus = page.locator('span:has-text("healthy")');
    await expect(healthStatus).toBeVisible();
    await expect(healthStatus).toHaveClass(/bg-green-100/);
  });

  test('Page is responsive on mobile', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('http://localhost:3002');
    
    // Wait for content to load
    await page.waitForSelector('h1:has-text("TrackAppointments")', { timeout: 10000 });
    
    // Verify main elements are still visible on mobile
    await expect(page.locator('h1:has-text("TrackAppointments")')).toBeVisible();
    await expect(page.locator('h2:has-text("Attribution Tracking Platform")')).toBeVisible();
    
    // Check that feature cards are visible (they should stack on mobile)
    await expect(page.locator('text=Advanced Attribution Models')).toBeVisible();
    await expect(page.locator('text=Privacy-Compliant Design')).toBeVisible();
  });

  test('No JavaScript errors in console', async ({ page }) => {
    const consoleErrors = [];
    
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });
    
    await page.goto('http://localhost:3002');
    await page.waitForLoadState('networkidle');
    
    // Wait a bit more to catch any delayed errors
    await page.waitForTimeout(3000);
    
    // Filter out known non-critical errors
    const criticalErrors = consoleErrors.filter(error => 
      !error.includes('favicon.ico') && 
      !error.includes('icon-192.png') &&
      !error.includes('manifest')
    );
    
    expect(criticalErrors).toHaveLength(0);
  });
});