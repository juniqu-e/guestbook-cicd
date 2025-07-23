package com.guestbook.guestbook.controller;

import com.guestbook.guestbook.entity.GuestbookEntry;
import com.guestbook.guestbook.repository.GuestbookRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/guestbook")
@CrossOrigin(origins = "*") // 프론트엔드에서 접근 허용
public class GuestbookController {
    
    private final GuestbookRepository guestbookRepository;
    
    // Constructor Injection 사용 (Spring 4.3+ 에서는 @Autowired 생략 가능)
    public GuestbookController(GuestbookRepository guestbookRepository) {
        this.guestbookRepository = guestbookRepository;
    }
    
    // 모든 방명록 엔트리 조회 (최신순)
    @GetMapping
    public List<GuestbookEntry> getAllEntries() {
        return guestbookRepository.findAllOrderByCreatedAtDesc();
    }
    
    // 새 방명록 엔트리 생성
    @PostMapping
    public ResponseEntity<GuestbookEntry> createEntry(@RequestBody GuestbookEntry entry) {
        // 입력값 검증
        if (entry.getName() == null || entry.getName().trim().isEmpty()) {
            return ResponseEntity.badRequest().build();
        }
        if (entry.getContent() == null || entry.getContent().trim().isEmpty()) {
            return ResponseEntity.badRequest().build();
        }
        
        // 데이터 저장
        GuestbookEntry savedEntry = guestbookRepository.save(entry);
        return ResponseEntity.ok(savedEntry);
    }
    
    // 방명록 엔트리 삭제
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEntry(@PathVariable Long id) {
        if (guestbookRepository.existsById(id)) {
            guestbookRepository.deleteById(id);
            return ResponseEntity.ok().build();
        }
        return ResponseEntity.notFound().build();
    }
    
    // 특정 ID의 방명록 엔트리 조회
    @GetMapping("/{id}")
    public ResponseEntity<GuestbookEntry> getEntry(@PathVariable Long id) {
        return guestbookRepository.findById(id)
                .map(entry -> ResponseEntity.ok().body(entry))
                .orElse(ResponseEntity.notFound().build());
    }
}