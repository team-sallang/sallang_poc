// Supabase 설정 파일
// 이 파일은 Supabase 클라이언트 초기화 및 설정을 담당합니다.

// Supabase 연결 정보
const SUPABASE_CONFIG = {
    url: 'http://localhost:8000',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
};

// WebRTC ICE 서버 설정
const ICE_SERVERS = [
    // Google STUN 서버
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    
    // 로컬 TURN 서버 (CoTURN)
    {
        urls: 'turn:localhost:3478',
        username: 'testuser',
        credential: 'testpass'
    },
    
    // 추가 TURN 서버 (필요시)
    // {
    //     urls: 'turn:your-turn-server.com:3478',
    //     username: 'your-username',
    //     credential: 'your-password'
    // }
];

// WebRTC 설정
const RTC_CONFIGURATION = {
    iceServers: ICE_SERVERS,
    iceCandidatePoolSize: 10
};

// Supabase 클라이언트 초기화
let supabaseClient = null;

// Supabase 클라이언트 초기화 함수
function initializeSupabase() {
    try {
        if (typeof window.supabase === 'undefined') {
            throw new Error('Supabase 라이브러리가 로드되지 않았습니다.');
        }
        
        supabaseClient = window.supabase.createClient(
            SUPABASE_CONFIG.url,
            SUPABASE_CONFIG.anonKey
        );
        
        console.log('Supabase 클라이언트 초기화 완료');
        return supabaseClient;
    } catch (error) {
        console.error('Supabase 클라이언트 초기화 실패:', error);
        return null;
    }
}

// Supabase 클라이언트 가져오기
function getSupabaseClient() {
    if (!supabaseClient) {
        return initializeSupabase();
    }
    return supabaseClient;
}

// 연결 상태 확인
async function checkSupabaseConnection() {
    try {
        const client = getSupabaseClient();
        if (!client) {
            throw new Error('Supabase 클라이언트가 초기화되지 않았습니다.');
        }
        
        // 간단한 쿼리로 연결 상태 확인
        const { data, error } = await client
            .from('webrtc_rooms')
            .select('count')
            .limit(1);
            
        if (error) {
            throw error;
        }
        
        console.log('Supabase 연결 상태: 정상');
        return true;
    } catch (error) {
        console.error('Supabase 연결 실패:', error);
        return false;
    }
}

// Realtime 채널 생성
function createRealtimeChannel(roomId, onMessage) {
    try {
        const client = getSupabaseClient();
        if (!client) {
            throw new Error('Supabase 클라이언트가 초기화되지 않았습니다.');
        }
        
        const channel = client
            .channel(`webrtc-signaling-${roomId}`)
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: 'webrtc_signaling',
                filter: `room_id=eq.${roomId}`
            }, (payload) => {
                if (onMessage && typeof onMessage === 'function') {
                    onMessage(payload.new);
                }
            });
            
        return channel;
    } catch (error) {
        console.error('Realtime 채널 생성 실패:', error);
        return null;
    }
}

// 시그널링 메시지 전송
async function sendSignalingMessage(roomId, userId, messageType, messageData) {
    try {
        const client = getSupabaseClient();
        if (!client) {
            throw new Error('Supabase 클라이언트가 초기화되지 않았습니다.');
        }
        
        const { data, error } = await client
            .from('webrtc_signaling')
            .insert({
                room_id: roomId,
                user_id: userId,
                message_type: messageType,
                message_data: messageData
            })
            .select();
            
        if (error) {
            throw error;
        }
        
        console.log(`${messageType} 메시지 전송 완료:`, data);
        return data;
    } catch (error) {
        console.error(`${messageType} 메시지 전송 실패:`, error);
        throw error;
    }
}

// 방 생성 또는 조회
async function createOrGetRoom(roomId, userId) {
    try {
        const client = getSupabaseClient();
        if (!client) {
            throw new Error('Supabase 클라이언트가 초기화되지 않았습니다.');
        }
        
        // 기존 방 조회
        const { data: existingRoom, error: selectError } = await client
            .from('webrtc_rooms')
            .select('*')
            .eq('id', roomId)
            .single();
            
        if (selectError && selectError.code === 'PGRST116') {
            // 방이 없으면 생성
            const { data: newRoom, error: insertError } = await client
                .from('webrtc_rooms')
                .insert({
                    id: roomId,
                    created_by: userId
                })
                .select()
                .single();
                
            if (insertError) {
                throw insertError;
            }
            
            console.log('새 방 생성 완료:', newRoom);
            return { room: newRoom, isNew: true };
        } else if (selectError) {
            throw selectError;
        } else {
            console.log('기존 방 조회 완료:', existingRoom);
            return { room: existingRoom, isNew: false };
        }
    } catch (error) {
        console.error('방 생성/조회 실패:', error);
        throw error;
    }
}

// 방 비활성화
async function deactivateRoom(roomId) {
    try {
        const client = getSupabaseClient();
        if (!client) {
            throw new Error('Supabase 클라이언트가 초기화되지 않았습니다.');
        }
        
        const { error } = await client
            .from('webrtc_rooms')
            .update({ is_active: false })
            .eq('id', roomId);
            
        if (error) {
            throw error;
        }
        
        console.log('방 비활성화 완료:', roomId);
        return true;
    } catch (error) {
        console.error('방 비활성화 실패:', error);
        return false;
    }
}

// 설정 내보내기
window.SupabaseConfig = {
    SUPABASE_CONFIG,
    RTC_CONFIGURATION,
    initializeSupabase,
    getSupabaseClient,
    checkSupabaseConnection,
    createRealtimeChannel,
    sendSignalingMessage,
    createOrGetRoom,
    deactivateRoom
};

// 페이지 로드 시 자동 초기화
document.addEventListener('DOMContentLoaded', () => {
    initializeSupabase();
});
