import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL;

function App() {
  const [entries, setEntries] = useState([]); // 기본값을 빈 배열로 설정
  const [name, setName] = useState('');
  const [content, setContent] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    // 디버깅용 콘솔 로그 추가
    console.log('API_BASE_URL:', API_BASE_URL);
    fetchEntries();
  }, []);

  const fetchEntries = async () => {
    try {
      setError('');
      console.log('Fetching entries from:', `${API_BASE_URL}/guestbook`);
      
      const response = await axios.get(`${API_BASE_URL}/guestbook`);
      
      // 디버깅용 로그
      console.log('API Response:', response);
      console.log('Response data:', response.data);
      console.log('Is array?', Array.isArray(response.data));
      
      // 배열인지 확인 후 설정
      if (Array.isArray(response.data)) {
        setEntries(response.data);
      } else {
        console.error('Response data is not an array:', response.data);
        setEntries([]); // 배열이 아니면 빈 배열로 설정
        setError('서버에서 올바른 데이터를 받지 못했습니다.');
      }
    } catch (error) {
      console.error('Failed to fetch entries:', error);
      console.error('Error details:', {
        message: error.message,
        response: error.response,
        request: error.request
      });
      
      setEntries([]); // 오류 시 빈 배열로 설정
      setError(`방명록을 불러오는데 실패했습니다: ${error.message}`);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!name.trim() || !content.trim()) {
      setError('이름과 내용을 모두 입력해주세요.');
      return;
    }

    setLoading(true);
    setError('');
    
    try {
      console.log('Creating entry:', { name: name.trim(), content: content.trim() });
      
      await axios.post(`${API_BASE_URL}/guestbook`, {
        name: name.trim(),
        content: content.trim()
      });
      
      setName('');
      setContent('');
      await fetchEntries();
      setError('');
    } catch (error) {
      console.error('Failed to create entry:', error);
      setError(`메시지 작성에 실패했습니다: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('정말로 삭제하시겠습니까?')) {
      return;
    }

    try {
      await axios.delete(`${API_BASE_URL}/guestbook/${id}`);
      await fetchEntries();
      setError('');
    } catch (error) {
      console.error('Failed to delete entry:', error);
      setError(`메시지 삭제에 실패했습니다: ${error.message}`);
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleString('ko-KR', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  // 디버깅 정보 화면에 표시
  console.log('Current state:', { entries, error, loading });

  return (
    <div className="app">
      <div className="container">
        <h1 className="title">방명록</h1>

        {/* 디버깅 정보 표시 */}
        <div style={{ 
          background: '#f0f0f0', 
          padding: '1rem', 
          margin: '1rem 0', 
          borderRadius: '8px',
          fontSize: '0.875rem',
          fontFamily: 'monospace'
        }}>
          <strong>디버깅 정보:</strong><br/>
          API URL: {API_BASE_URL}<br/>
          Entries type: {typeof entries}<br/>
          Entries is array: {Array.isArray(entries).toString()}<br/>
          Entries length: {Array.isArray(entries) ? entries.length : 'N/A'}<br/>
          Entries: {JSON.stringify(entries)}
        </div>

        {/* 오류 메시지 */}
        {error && (
          <div className="error">
            {error}
          </div>
        )}

        {/* 메시지 작성 폼 */}
        <div className="form-container">
          <h2 className="form-title">메시지 남기기</h2>
          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label className="label">이름</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="input"
                placeholder="이름을 입력하세요"
                maxLength={50}
                disabled={loading}
              />
            </div>
            
            <div className="form-group">
              <label className="label">내용</label>
              <textarea
                value={content}
                onChange={(e) => setContent(e.target.value)}
                className="textarea"
                placeholder="메시지를 입력하세요..."
                maxLength={1000}
                disabled={loading}
              />
              <div style={{ 
                fontSize: '0.875rem', 
                color: '#718096', 
                textAlign: 'right', 
                marginTop: '0.5rem' 
              }}>
                {content.length}/1000
              </div>
            </div>
            
            <button
              type="submit"
              disabled={loading || !name.trim() || !content.trim()}
              className="button"
            >
              {loading ? '작성 중...' : '메시지 작성'}
            </button>
          </form>
        </div>

        {/* 메시지 목록 */}
        <div className="messages">
          {/* 통계 카드 */}
          <div className="stats-card">
            <span className="stats-number">{Array.isArray(entries) ? entries.length : 0}</span>
            <span className="stats-label">총 메시지</span>
          </div>

          {!Array.isArray(entries) ? (
            <div className="error">
              데이터 형식이 올바르지 않습니다. 개발자 도구의 콘솔을 확인해주세요.
            </div>
          ) : entries.length === 0 ? (
            <div className="empty-state">
              <p>아직 작성된 메시지가 없습니다.</p>
              <p style={{ fontSize: '0.875rem', marginTop: '0.5rem', opacity: 0.7 }}>
                첫 번째 메시지를 남겨보세요!
              </p>
            </div>
          ) : (
            entries.map((entry, index) => (
              <div 
                key={entry.id} 
                className="message-card"
                style={{ animationDelay: `${index * 0.1}s` }}
              >
                <div className="message-header">
                  <h3 className="message-name">{entry.name}</h3>
                  <button
                    onClick={() => handleDelete(entry.id)}
                    className="delete-button"
                    title="삭제"
                  >
                    삭제
                  </button>
                </div>
                
                <p className="message-content">{entry.content}</p>
                
                <div className="message-date">
                  {formatDate(entry.createdAt)}
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

export default App;