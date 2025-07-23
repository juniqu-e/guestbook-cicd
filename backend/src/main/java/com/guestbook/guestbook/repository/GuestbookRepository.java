package com.guestbook.guestbook.repository;

import com.guestbook.guestbook.entity.GuestbookEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface GuestbookRepository extends JpaRepository<GuestbookEntry, Long> {
    
    // 최신 순으로 정렬해서 모든 엔트리 조회
    @Query("SELECT g FROM GuestbookEntry g ORDER BY g.createdAt DESC")
    List<GuestbookEntry> findAllOrderByCreatedAtDesc();
}