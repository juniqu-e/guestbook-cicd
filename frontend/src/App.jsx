import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL;

function App() {
  const [entries, setEntries] = useState([]);
  const [name, setName] = useState('');
  const [content, setContent] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchEntries();
  }, []);

  const fetchEntries = async () => {
    try {
      setError('');
      const response = await axios.get(`${API_BASE_URL}/guestbook`);
      
      if (Array.isArray(response.data)) {
        setEntries(response.data);
      } else {
        setEntries([]);
        setError('서버에서 올바른 데이터를 받지 못했습니다.');
      }
    } catch (error) {
      setEntries([]);
      setError('방명록을 불러오는데 실패했습니다.');
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
      await axios.post(`${API_BASE_URL}/guestbook`, {
        name: name.trim(),
        content: content.trim()
      });
      
      setName('');
      setContent('');
      await fetchEntries();
      setError('');
    } catch (error) {
      setError('메시지 작성에 실패했습니다.');
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
      setError('메시지 삭제에 실패했습니다.');
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

  return (
    <div className="app">
      <div className="container">
        <h1 className="title">방명록</h1>

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
            <span className="stats-number">{entries.length}</span>
            <span className="stats-label">총 메시지</span>
          </div>

          {entries.length === 0 ? (
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