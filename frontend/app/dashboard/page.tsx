'use client'

import { useState, useEffect } from 'react'

interface Campaign {
  id: string
  name: string
  platform: string
  status: 'active' | 'paused' | 'completed'
  clicks: number
  conversions: number
  spend: number
  revenue: number
}

interface Attribution {
  id: string
  timestamp: string
  source: string
  medium: string
  campaign: string
  conversion_value: number
  attribution_confidence: number
}

export default function Dashboard() {
  const [campaigns, setCampaigns] = useState<Campaign[]>([])
  const [attributions, setAttributions] = useState<Attribution[]>([])
  const [activeTab, setActiveTab] = useState<'overview' | 'campaigns' | 'attributions' | 'settings'>('overview')
  const [loading, setLoading] = useState(true)
  const [connectingProvider, setConnectingProvider] = useState<string | null>(null)
  
  // Settings form state
  const [businessSettings, setBusinessSettings] = useState({
    business_name: 'Your Business Name',
    default_currency: 'USD',
    timezone: 'Eastern Time (ET)'
  })
  const [savingSettings, setSavingSettings] = useState(false)
  
  // OAuth connection state
  const [oauthStatus, setOauthStatus] = useState({
    facebook: { connected: false, loading: false },
    google: { connected: false, loading: false },
    square: { connected: false, loading: false },
    stripe: { connected: false, loading: false }
  })

  // Fetch OAuth connection status
  const fetchOAuthStatus = async () => {
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8002'
      const response = await fetch(`${apiUrl}/api/v1/oauth/status?business_id=demo-business-123`)
      const data = await response.json()
      
      if (response.ok) {
        const newStatus = {}
        data.connections.forEach(conn => {
          newStatus[conn.provider] = {
            connected: conn.status === 'connected',
            loading: false,
            account_name: conn.account_name,
            last_sync: conn.last_sync
          }
        })
        setOauthStatus(newStatus)
      }
    } catch (error) {
      console.error('Error fetching OAuth status:', error)
    }
  }

  const handleOAuthConnect = async (provider: string) => {
    // Update loading state for this specific provider
    setOauthStatus(prev => ({
      ...prev,
      [provider]: { ...prev[provider], loading: true }
    }))
    
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8002'
      
      const response = await fetch(`${apiUrl}/api/v1/oauth/connect`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          provider: provider,
          business_id: 'demo-business-123',
          redirect_url: `${window.location.origin}/oauth/callback`
        })
      })
      
      const data = await response.json()
      
      if (response.ok) {
        console.log(`Redirecting to ${provider} OAuth:`, data.authorization_url)
        // Redirect to real OAuth provider
        window.location.href = data.authorization_url
      } else {
        console.error('OAuth connection failed:', data)
        alert(`Failed to connect to ${provider}. Please try again.`)
        setOauthStatus(prev => ({
          ...prev,
          [provider]: { ...prev[provider], loading: false }
        }))
      }
    } catch (error) {
      console.error('OAuth connection error:', error)
      alert(`Error connecting to ${provider}. Please try again.`)
      setOauthStatus(prev => ({
        ...prev,
        [provider]: { ...prev[provider], loading: false }
      }))
    }
  }

  const handleSaveSettings = async () => {
    setSavingSettings(true)
    
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8002'
      
      const response = await fetch(`${apiUrl}/api/v1/business/settings?business_id=demo-business-123`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(businessSettings)
      })
      
      const data = await response.json()
      
      if (response.ok) {
        alert('Settings saved successfully!')
        console.log('Settings saved:', data)
      } else {
        console.error('Failed to save settings:', data)
        alert('Failed to save settings. Please try again.')
      }
    } catch (error) {
      console.error('Settings save error:', error)
      alert('Error saving settings. Please try again.')
    } finally {
      setSavingSettings(false)
    }
  }

  useEffect(() => {
    // Simulate loading data and fetch OAuth status
    setLoading(true)
    fetchOAuthStatus()
    setTimeout(() => {
      setCampaigns([
        {
          id: '1',
          name: 'Facebook Lead Gen Q4',
          platform: 'Facebook',
          status: 'active',
          clicks: 1247,
          conversions: 89,
          spend: 2450.00,
          revenue: 8900.00
        },
        {
          id: '2', 
          name: 'Google Search - Hair Salon',
          platform: 'Google Ads',
          status: 'active',
          clicks: 892,
          conversions: 67,
          spend: 1890.00,
          revenue: 6700.00
        },
        {
          id: '3',
          name: 'Instagram Story Ads',
          platform: 'Instagram',
          status: 'paused',
          clicks: 634,
          conversions: 23,
          spend: 890.00,
          revenue: 2300.00
        }
      ])

      setAttributions([
        {
          id: '1',
          timestamp: '2024-08-04T12:30:00Z',
          source: 'facebook',
          medium: 'cpc',
          campaign: 'Facebook Lead Gen Q4',
          conversion_value: 120.00,
          attribution_confidence: 0.94
        },
        {
          id: '2',
          timestamp: '2024-08-04T12:25:00Z', 
          source: 'google',
          medium: 'organic',
          campaign: 'Google Search - Hair Salon',
          conversion_value: 85.00,
          attribution_confidence: 0.87
        }
      ])
      
      setLoading(false)
    }, 1000)
  }, [])

  const StatusBadge = ({ status }: { status: string }) => {
    const colors = {
      active: 'bg-green-100 text-green-800',
      paused: 'bg-yellow-100 text-yellow-800', 
      completed: 'bg-gray-100 text-gray-800'
    }
    return (
      <span className={`px-2 py-1 rounded-full text-xs font-medium ${colors[status as keyof typeof colors]}`}>
        {status.charAt(0).toUpperCase() + status.slice(1)}
      </span>
    )
  }

  const OverviewTab = () => (
    <div className="space-y-6">
      {/* Quick Actions */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Quick Actions</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button className="flex items-center p-4 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
            <span className="text-blue-600 mr-3 font-bold">+</span>
            <span className="font-medium">Create Campaign</span>
          </button>
          <button className="flex items-center p-4 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
            <span className="text-green-600 mr-3 font-bold">📊</span>
            <span className="font-medium">View Analytics</span>
          </button>
          <button className="flex items-center p-4 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
            <span className="text-purple-600 mr-3 font-bold">⚙️</span>
            <span className="font-medium">Settings</span>
          </button>
        </div>
      </div>

      {/* Live Attribution Feed */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Live Attribution Events</h3>
        <div className="space-y-3">
          {attributions.map((attr) => (
            <div key={attr.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div className="flex items-center space-x-3">
                <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <div>
                  <p className="font-medium text-gray-900">{attr.campaign}</p>
                  <p className="text-sm text-gray-600">{attr.source} → ${attr.conversion_value}</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-sm font-medium text-green-600">
                  {Math.round(attr.attribution_confidence * 100)}% confidence
                </p>
                <p className="text-xs text-gray-500">
                  {new Date(attr.timestamp).toLocaleTimeString()}
                </p>
              </div>
            </div>
          ))}
          <div className="text-center py-4">
            <button className="text-blue-600 hover:text-blue-800 font-medium">
              View All Events →
            </button>
          </div>
        </div>
      </div>
    </div>
  )

  const CampaignsTab = () => (
    <div className="bg-white rounded-lg shadow">
      <div className="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
        <h3 className="text-lg font-medium text-gray-900">Campaign Performance</h3>
        <button className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors">
          + Add Campaign
        </button>
      </div>
      
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Campaign
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Platform
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Clicks
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Conversions
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Spend
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Revenue
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                ROAS
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {campaigns.map((campaign) => (
              <tr key={campaign.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="font-medium text-gray-900">{campaign.name}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {campaign.platform}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <StatusBadge status={campaign.status} />
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {campaign.clicks.toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {campaign.conversions}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  ${campaign.spend.toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  ${campaign.revenue.toLocaleString()}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {(campaign.revenue / campaign.spend).toFixed(2)}x
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button className="text-blue-600 hover:text-blue-900 mr-3">
                    👁️ View
                  </button>
                  <button className="text-gray-600 hover:text-gray-900">
                    ⚙️ Edit
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )

  const AttributionsTab = () => (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* Attribution Feed */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Live Attribution Feed</h3>
        <div className="space-y-3 max-h-96 overflow-y-auto">
          {attributions.map((attr) => (
            <div key={attr.id} className="border border-gray-200 rounded-lg p-4">
              <div className="flex justify-between items-start mb-2">
                <span className="font-medium text-gray-900">{attr.campaign}</span>
                <span className="text-sm text-gray-500">
                  {new Date(attr.timestamp).toLocaleString()}
                </span>
              </div>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-gray-600">Source:</span>
                  <span className="ml-2 font-medium">{attr.source}</span>
                </div>
                <div>
                  <span className="text-gray-600">Value:</span>
                  <span className="ml-2 font-medium">${attr.conversion_value}</span>
                </div>
              </div>
              <div className="mt-2">
                <div className="flex items-center justify-between text-sm">
                  <span className="text-gray-600">Confidence:</span>
                  <span className="font-medium text-green-600">
                    {Math.round(attr.attribution_confidence * 100)}%
                  </span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2 mt-1">
                  <div 
                    className="bg-green-600 h-2 rounded-full" 
                    style={{ width: `${attr.attribution_confidence * 100}%` }}
                  ></div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Attribution Settings */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Attribution Model Settings</h3>
        <div className="space-y-4">
          <div className="border border-gray-200 rounded-lg p-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Attribution Window
            </label>
            <select className="w-full border border-gray-300 rounded-md px-3 py-2">
              <option>7 days</option>
              <option>14 days</option>
              <option>30 days</option>
              <option>90 days</option>
            </select>
          </div>

          <div className="border border-gray-200 rounded-lg p-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Confidence Threshold
            </label>
            <input 
              type="range" 
              min="0.5" 
              max="1" 
              step="0.01" 
              className="w-full"
              defaultValue="0.85"
            />
            <div className="flex justify-between text-sm text-gray-600 mt-1">
              <span>50%</span>
              <span>85%</span>
              <span>100%</span>
            </div>
          </div>

          <button className="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 transition-colors">
            Update Settings
          </button>
        </div>
      </div>
    </div>
  )

  const SettingsTab = () => {
    const integrations = [
      { 
        name: 'Facebook Ads', 
        description: 'Track conversions from your Facebook advertising campaigns',
        provider: 'facebook',
        icon: '📘'
      },
      { 
        name: 'Google Ads', 
        description: 'Monitor performance of your Google advertising spend',
        provider: 'google',
        icon: '🔍'
      },
      { 
        name: 'Square Payments', 
        description: 'Track revenue from your Square point-of-sale system',
        provider: 'square',
        icon: '⬜'
      },
      { 
        name: 'Stripe Payments', 
        description: 'Monitor online payments and subscription revenue',
        provider: 'stripe',
        icon: '💳'
      }
    ]

    return (
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Connect Your Accounts */}
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-2">Connect Your Accounts</h3>
          <p className="text-sm text-gray-600 mb-6">Connect your business accounts to start tracking attribution automatically. One-click setup, no technical knowledge required.</p>
          <div className="space-y-4">
            {integrations.map((integration) => {
              const providerStatus = oauthStatus[integration.provider] || { connected: false, loading: false }
              const isConnected = providerStatus.connected
              const isLoading = providerStatus.loading
              
              return (
                <div key={integration.name} className="p-4 border border-gray-200 rounded-xl hover:shadow-md transition-all">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-4">
                      <div className="w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center text-xl">
                        {integration.icon}
                      </div>
                      <div>
                        <h4 className="font-semibold text-gray-900">{integration.name}</h4>
                        <p className="text-sm text-gray-600">{integration.description}</p>
                      </div>
                    </div>
                    <button 
                      onClick={() => !isConnected && !isLoading ? handleOAuthConnect(integration.provider) : undefined}
                      disabled={isLoading || isConnected}
                      className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                        isConnected 
                          ? 'bg-green-100 text-green-800 cursor-default' 
                          : isLoading
                            ? 'bg-gray-400 text-white cursor-not-allowed'
                            : 'bg-blue-600 text-white hover:bg-blue-700 cursor-pointer'
                      }`}
                    >
                      {isLoading 
                        ? 'Connecting...' 
                        : isConnected 
                          ? 'Connected ✓'
                          : `Connect with ${integration.name.replace(' Ads', '').replace(' Payments', '')}`}
                    </button>
                  </div>
                </div>
              )
            })}
          </div>
        
        {/* Help Section */}
        <div className="mt-6 p-4 bg-blue-50 rounded-lg">
          <div className="flex items-start space-x-3">
            <div className="text-blue-600 text-lg">💡</div>
            <div>
              <h4 className="font-medium text-blue-900">Need Help?</h4>
              <p className="text-sm text-blue-800 mt-1">
                Our setup wizard guides you through connecting each account in under 2 minutes. 
                <button className="underline ml-1">Start Setup Guide</button>
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Platform Settings */}
      <div className="bg-white rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Platform Settings</h3>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Business Name
            </label>
            <input 
              type="text" 
              className="w-full border border-gray-300 rounded-md px-3 py-2"
              placeholder="Your Business Name"
              value={businessSettings.business_name}
              onChange={(e) => setBusinessSettings({...businessSettings, business_name: e.target.value})}
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Default Currency
            </label>
            <select 
              className="w-full border border-gray-300 rounded-md px-3 py-2"
              value={businessSettings.default_currency}
              onChange={(e) => setBusinessSettings({...businessSettings, default_currency: e.target.value})}
            >
              <option value="USD">USD</option>
              <option value="EUR">EUR</option>
              <option value="GBP">GBP</option>
              <option value="CAD">CAD</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Time Zone
            </label>
            <select 
              className="w-full border border-gray-300 rounded-md px-3 py-2"
              value={businessSettings.timezone}
              onChange={(e) => setBusinessSettings({...businessSettings, timezone: e.target.value})}
            >
              <option value="Eastern Time (ET)">Eastern Time (ET)</option>
              <option value="Central Time (CT)">Central Time (CT)</option>
              <option value="Mountain Time (MT)">Mountain Time (MT)</option>
              <option value="Pacific Time (PT)">Pacific Time (PT)</option>
            </select>
          </div>

          <button 
            onClick={handleSaveSettings}
            disabled={savingSettings}
            className="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"
          >
            {savingSettings ? 'Saving...' : 'Save Settings'}
          </button>
        </div>
      </div>
    </div>
    )
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading Dashboard...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">TA</span>
              </div>
              <h1 className="text-2xl font-bold text-gray-900">TrackAppointments Dashboard</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="px-3 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800 flex items-center">
                <span className="w-2 h-2 bg-green-500 rounded-full mr-2 animate-pulse"></span>
                Live
              </span>
              <button 
                onClick={() => window.location.href = '/'}
                className="text-gray-600 hover:text-gray-900 font-medium"
              >
                ← Back to Home
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Navigation Tabs */}
      <div className="bg-white border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <nav className="flex space-x-8">
            {[
              { key: 'overview', label: 'Overview', emoji: '📊' },
              { key: 'campaigns', label: 'Campaigns', emoji: '🎯' },
              { key: 'attributions', label: 'Attribution', emoji: '🔗' },
              { key: 'settings', label: 'Settings', emoji: '⚙️' }
            ].map((tab) => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key as any)}
                className={`py-4 px-1 border-b-2 font-medium text-sm flex items-center ${
                  activeTab === tab.key
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <span className="mr-2">{tab.emoji}</span>
                {tab.label}
              </button>
            ))}
          </nav>
        </div>
      </div>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {activeTab === 'overview' && <OverviewTab />}
        {activeTab === 'campaigns' && <CampaignsTab />}
        {activeTab === 'attributions' && <AttributionsTab />}
        {activeTab === 'settings' && <SettingsTab />}
      </main>
    </div>
  )
}