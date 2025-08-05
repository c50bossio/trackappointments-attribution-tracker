#!/usr/bin/env node

/**
 * TrackAppointments Production Health Monitor
 * Simple monitoring script for production health checks
 */

import https from 'https';

const ENDPOINTS = {
  frontend: 'https://trackappointments.com',
  api: 'https://api.trackappointments.com/health',
  oauth: 'https://api.trackappointments.com/api/v1/oauth/providers'
};

const TIMEOUT = 10000; // 10 seconds

function checkEndpoint(name, url) {
  return new Promise((resolve) => {
    const startTime = Date.now();
    
    const req = https.get(url, { timeout: TIMEOUT }, (res) => {
      const endTime = Date.now();
      const responseTime = endTime - startTime;
      
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const isHealthy = res.statusCode >= 200 && res.statusCode < 400;
        resolve({
          name,
          url,
          status: res.statusCode,
          responseTime,
          healthy: isHealthy,
          error: null
        });
      });
    });
    
    req.on('error', (error) => {
      resolve({
        name,
        url,
        status: 0,
        responseTime: Date.now() - startTime,
        healthy: false,
        error: error.message
      });
    });
    
    req.on('timeout', () => {
      req.destroy();
      resolve({
        name,
        url,
        status: 0,
        responseTime: TIMEOUT,
        healthy: false,
        error: 'Request timeout'
      });
    });
  });
}

async function runHealthChecks() {
  console.log('🔍 TrackAppointments Production Health Check');
  console.log('=' .repeat(50));
  console.log(`Timestamp: ${new Date().toISOString()}`);
  console.log('');
  
  const results = await Promise.all(
    Object.entries(ENDPOINTS).map(([name, url]) => checkEndpoint(name, url))
  );
  
  let allHealthy = true;
  
  results.forEach(result => {
    const statusIcon = result.healthy ? '✅' : '❌';
    const responseTimeColor = result.responseTime < 1000 ? '🟢' : result.responseTime < 3000 ? '🟡' : '🔴';
    
    console.log(`${statusIcon} ${result.name.toUpperCase()}`);
    console.log(`   URL: ${result.url}`);
    console.log(`   Status: ${result.status}`);
    console.log(`   Response Time: ${responseTimeColor} ${result.responseTime}ms`);
    
    if (result.error) {
      console.log(`   Error: ${result.error}`);
    }
    
    console.log('');
    
    if (!result.healthy) {
      allHealthy = false;
    }
  });
  
  console.log('=' .repeat(50));
  console.log(`Overall Health: ${allHealthy ? '✅ HEALTHY' : '❌ UNHEALTHY'}`);
  
  // Exit with error code if unhealthy (useful for CI/CD)
  process.exit(allHealthy ? 0 : 1);
}

// Run health checks
runHealthChecks().catch(console.error);