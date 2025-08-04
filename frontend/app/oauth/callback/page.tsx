'use client'

import { useEffect, useState } from 'react'
import { useSearchParams, useRouter } from 'next/navigation'

export default function OAuthCallback() {
  const [status, setStatus] = useState('processing')
  const [message, setMessage] = useState('Processing your connection...')
  const searchParams = useSearchParams()
  const router = useRouter()
  
  useEffect(() => {
    const success = searchParams.get('oauth_success')
    const error = searchParams.get('oauth_error')
    const connectionId = searchParams.get('connection_id')
    
    if (success) {
      setStatus('success')
      setMessage(`Successfully connected ${success}!`)
      
      // Redirect to dashboard after 2 seconds
      setTimeout(() => {
        router.push('/dashboard')
      }, 2000)
    } else if (error) {
      setStatus('error')
      setMessage(`Connection failed: ${error}`)
      
      // Redirect to dashboard after 3 seconds
      setTimeout(() => {
        router.push('/dashboard')
      }, 3000)
    } else {
      // Handle direct OAuth callback from provider
      const code = searchParams.get('code')
      const state = searchParams.get('state')
      
      if (code && state) {
        // This would normally be handled by the backend OAuth callback
        setStatus('success')
        setMessage('Connection successful! Redirecting...')
        
        setTimeout(() => {
          router.push('/dashboard')
        }, 2000)
      } else {
        setStatus('error')
        setMessage('Invalid callback parameters')
        
        setTimeout(() => {
          router.push('/dashboard')
        }, 3000)
      }
    }
  }, [searchParams, router])
  
  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 via-blue-50 to-indigo-100 flex items-center justify-center">
      <div className="bg-white rounded-2xl shadow-xl p-8 max-w-md w-full mx-4">
        <div className="text-center">
          {status === 'processing' && (
            <>
              <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-2">Connecting Account</h2>
            </>
          )}
          
          {status === 'success' && (
            <>
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-green-600 text-2xl">✓</span>
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-2">Connection Successful!</h2>
            </>
          )}
          
          {status === 'error' && (
            <>
              <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-red-600 text-2xl">✗</span>
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-2">Connection Failed</h2>
            </>
          )}
          
          <p className="text-gray-600 mb-6">{message}</p>
          
          <button
            onClick={() => router.push('/dashboard')}
            className="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors"
          >
            Return to Dashboard
          </button>
        </div>
      </div>
    </div>
  )
}