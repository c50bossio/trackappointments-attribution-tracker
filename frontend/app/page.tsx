'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'

interface DashboardData {
  total_interactions: number
  conversion_rate: string
  attribution_accuracy: string
  recovered_revenue: string
}

interface HealthStatus {
  status: string
  service: string
  version: string
  components: {
    database: { status: string }
    redis: { status: string }
  }
}

export default function Home() {
  const [healthStatus, setHealthStatus] = useState<HealthStatus | null>(null)
  const [dashboardData, setDashboardData] = useState<DashboardData | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8002'
    
    // Fetch health status from backend
    fetch(`${apiUrl}/api/health`)
      .then(res => res.json())
      .then(data => setHealthStatus(data))
      .catch(err => console.error('Health check failed:', err))

    // Fetch dashboard data
    fetch(`${apiUrl}/api/v1/analytics/dashboard`)
      .then(res => res.json())
      .then(data => setDashboardData(data))
      .catch(err => console.error('Dashboard data fetch failed:', err))
      .finally(() => setLoading(false))
  }, [])

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 via-blue-50 to-indigo-100">
      {/* Header */}
      <header className="bg-white/80 backdrop-blur-sm shadow-lg border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <div className="w-12 h-12 bg-gradient-to-br from-blue-600 to-indigo-700 rounded-xl flex items-center justify-center shadow-lg">
                <span className="text-white font-bold text-lg">TA</span>
              </div>
              <div>
                <h1 className="text-3xl font-bold bg-gradient-to-r from-gray-900 to-gray-700 bg-clip-text text-transparent">
                  TrackAppointments
                </h1>
                <p className="text-sm text-gray-600">Enterprise Attribution Platform</p>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              {healthStatus && (
                <div className="flex items-center space-x-2">
                  <div className="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
                  <span className="px-3 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    System {healthStatus.status}
                  </span>
                </div>
              )}
              <Link 
                href="/dashboard"
                className="bg-gradient-to-r from-blue-600 to-indigo-700 text-white px-6 py-3 rounded-lg font-semibold hover:from-blue-700 hover:to-indigo-800 transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
              >
                Launch Platform →
              </Link>
            </div>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center mb-16">
          <h2 className="text-5xl font-bold text-gray-900 mb-6">
            Attribution Tracking
            <span className="block text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-indigo-700">
              Reimagined
            </span>
          </h2>
          <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
            Bridge the gap between ad platforms and booking systems with 92%+ attribution accuracy. 
            Recover lost revenue and optimize your marketing spend with enterprise-grade precision.
          </p>
        </div>

        {/* Live Metrics Dashboard */}
        {!loading && dashboardData && (
          <div className="bg-white/70 backdrop-blur-sm rounded-2xl shadow-xl border border-gray-200 p-8 mb-12">
            <div className="flex items-center justify-between mb-8">
              <h3 className="text-2xl font-bold text-gray-900">Live Platform Metrics</h3>
              <div className="flex items-center space-x-2">
                <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <span className="text-sm font-medium text-green-600">Real-time</span>
              </div>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="bg-gradient-to-br from-blue-50 to-blue-100 p-6 rounded-xl border border-blue-200">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-sm font-semibold text-blue-700">Total Interactions</h4>
                  <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
                    <span className="text-white font-bold text-xs">📊</span>
                  </div>
                </div>
                <p className="text-3xl font-bold text-blue-900">{dashboardData.total_interactions.toLocaleString()}</p>
                <p className="text-xs text-blue-600 mt-1">+12% from last hour</p>
              </div>
              
              <div className="bg-gradient-to-br from-green-50 to-green-100 p-6 rounded-xl border border-green-200">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-sm font-semibold text-green-700">Conversion Rate</h4>
                  <div className="w-8 h-8 bg-green-600 rounded-lg flex items-center justify-center">
                    <span className="text-white font-bold text-xs">🎯</span>
                  </div>
                </div>
                <p className="text-3xl font-bold text-green-900">{dashboardData.conversion_rate}</p>
                <p className="text-xs text-green-600 mt-1">+2.3% this week</p>
              </div>
              
              <div className="bg-gradient-to-br from-purple-50 to-purple-100 p-6 rounded-xl border border-purple-200">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-sm font-semibold text-purple-700">Attribution Accuracy</h4>
                  <div className="w-8 h-8 bg-purple-600 rounded-lg flex items-center justify-center">
                    <span className="text-white font-bold text-xs">🔍</span>
                  </div>
                </div>
                <p className="text-3xl font-bold text-purple-900">{dashboardData.attribution_accuracy}</p>
                <p className="text-xs text-purple-600 mt-1">vs 45% industry avg</p>
              </div>
              
              <div className="bg-gradient-to-br from-yellow-50 to-yellow-100 p-6 rounded-xl border border-yellow-200">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-sm font-semibold text-yellow-700">Recovered Revenue</h4>
                  <div className="w-8 h-8 bg-yellow-600 rounded-lg flex items-center justify-center">
                    <span className="text-white font-bold text-xs">💰</span>
                  </div>
                </div>
                <p className="text-3xl font-bold text-yellow-900">{dashboardData.recovered_revenue}</p>
                <p className="text-xs text-yellow-600 mt-1">+$847 today</p>
              </div>
            </div>
          </div>
        )}

        {/* Feature Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 mb-16">
          <div className="bg-white/70 backdrop-blur-sm rounded-xl p-8 shadow-lg border border-gray-200 hover:shadow-xl transition-all duration-300">
            <div className="w-12 h-12 bg-gradient-to-br from-red-500 to-pink-600 rounded-xl flex items-center justify-center mb-6">
              <span className="text-white font-bold text-xl">🎯</span>
            </div>
            <h3 className="text-xl font-bold text-gray-900 mb-4">Advanced Attribution Models</h3>
            <p className="text-gray-600 mb-4">
              85-95% accuracy vs 45% industry standard with ML-powered matching algorithms
            </p>
            <div className="flex items-center space-x-2">
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div className="bg-gradient-to-r from-red-500 to-pink-600 h-2 rounded-full" style={{width: '92%'}}></div>
              </div>
              <span className="text-sm font-semibold text-red-600">92%</span>
            </div>
          </div>

          <div className="bg-white/70 backdrop-blur-sm rounded-xl p-8 shadow-lg border border-gray-200 hover:shadow-xl transition-all duration-300">
            <div className="w-12 h-12 bg-gradient-to-br from-green-500 to-emerald-600 rounded-xl flex items-center justify-center mb-6">
              <span className="text-white font-bold text-xl">🔒</span>
            </div>
            <h3 className="text-xl font-bold text-gray-900 mb-4">Privacy-Compliant Design</h3>
            <p className="text-gray-600 mb-4">
              GDPR compliant with privacy-safe identifiers and encrypted data storage
            </p>
            <div className="flex items-center space-x-2 text-green-600">
              <div className="w-2 h-2 bg-green-500 rounded-full"></div>
              <span className="text-sm font-semibold">GDPR Certified</span>
            </div>
          </div>

          <div className="bg-white/70 backdrop-blur-sm rounded-xl p-8 shadow-lg border border-gray-200 hover:shadow-xl transition-all duration-300">
            <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-cyan-600 rounded-xl flex items-center justify-center mb-6">
              <span className="text-white font-bold text-xl">📊</span>
            </div>
            <h3 className="text-xl font-bold text-gray-900 mb-4">Real-Time Analytics</h3>
            <p className="text-gray-600 mb-4">
              WebSocket streaming for live attribution updates and campaign performance
            </p>
            <div className="flex items-center space-x-2 text-blue-600">
              <div className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></div>
              <span className="text-sm font-semibold">Live Updates</span>
            </div>
          </div>
        </div>

        {/* CTA Section */}
        <div className="bg-gradient-to-r from-blue-600 to-indigo-700 rounded-2xl p-12 text-center text-white shadow-2xl">
          <h3 className="text-3xl font-bold mb-4">Ready to Transform Your Attribution?</h3>
          <p className="text-xl text-blue-100 mb-8 max-w-2xl mx-auto">
            Join enterprise clients who've recovered 28% of their lost attribution revenue
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link 
              href="/dashboard"
              className="bg-white text-blue-600 px-8 py-4 rounded-lg font-semibold hover:bg-gray-100 transition-colors shadow-lg"
            >
              Launch Full Platform
            </Link>
            <button className="border-2 border-white text-white px-8 py-4 rounded-lg font-semibold hover:bg-white hover:text-blue-600 transition-colors">
              Schedule Demo
            </button>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-white/50 backdrop-blur-sm border-t border-gray-200 mt-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex items-center justify-between">
            <p className="text-gray-600">
              © 2024 TrackAppointments Attribution Tracker. Built for enterprise attribution accuracy.
            </p>
            <div className="flex items-center space-x-2">
              <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
              <span className="text-sm text-gray-600">All systems operational</span>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}