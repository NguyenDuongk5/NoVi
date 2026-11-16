<!-- 
  Tìm kiếm truyện theo từ khóa
  author: NvtDuong
  createdDate: 13/12/2025
-->
<template>
  <div class="filtered-container" ref="container">
    <!-- Tiêu đề tìm kiếm -->
    <h2 class="title" v-if="keyword">
      Kết quả tìm kiếm cho "{{ keyword }}"
    </h2>

    <!-- Không có kết quả -->
    <p v-if="results.length === 0 && keyword" class="no-result">
      Không tìm thấy truyện nào.
    </p>

    <!-- Thông tin đã load -->
    <p v-if="shown.length > 0" class="loaded-info">
      Đã hiển thị {{ shown.length }} / {{ results.length }} truyện
    </p>

    <!-- Grid truyện -->
    <div class="manga-grid">
      <div class="manga-item" v-for="m in shown" :key="m.manga_id" @click.stop="selectManga(m)">
        <img
          :src="m.manga_thumbnail || m.manga_image"
          class="thumbnail"
          alt="thumbnail"
        />
        <div class="info">
          <h3>{{ m.manga_title }}</h3>
          <p><b>Tác giả:</b> {{ m.manga_author || "Chưa rõ" }}</p>
          <p><b>Thể loại:</b> {{ m.category_names || "Chưa rõ" }}</p>
          <p><b>Ngày tạo:</b> {{ formatDate(m.created_date) }}</p>
        </div>
      </div>
    </div>

    <!-- Loading khi load thêm batch -->
    <div class="loading" v-if="isLoading">
      <div class="loader"></div>
      Đang tải thêm...
    </div>

    <!-- Hết dữ liệu -->
    <p v-if="shown.length >= results.length && results.length > 0" class="end-text">
      Bạn đã xem hết kết quả.
    </p>
  </div>

</template>

<script>
import { mangaApi } from "@/api/mangaApi";

export default {
  name: "FilteredMangas",
  emits: ["select", "select-history"],
  props: {
    keyword: {
      type: String, 
      default: ""
    }
  },

  data() {
    return {
      results: [],
      shown: [],
      isLoading: false,
      batchSize: 8,
      searchHistory: []
    };
  },

  methods: {
    /**
     * Gọi API tìm kiếm truyện theo từ khóa
     * author : NvtDuong
     * Date: 13/12/25
     */
    async loadSearch() {
      const me = this;
      // loại bỏ khoảng trắng thừa
      const key = me.keyword?.trim();

      // nếu không có keyword thì reset dữ liệu
      if (!key) {
        me.results = [];
        me.shown = [];
        return;
      }

      me.isLoading = true;
      try {
        // gọi API search
        const res = await mangaApi.search(key);

        // lưu toàn bộ kết quả
        me.results = res.data || [];

        // chỉ hiển thị batch đầu tiên
        me.shown = me.results.slice(0, me.batchSize);

        // lưu lịch sử tìm kiếm
        me.saveHistory(key);
      } catch (err) {
        console.error("Search error:", err);
        me.results = [];
        me.shown = [];
      }
      me.isLoading = false;
    },

    /**
     * Lưu lịch sử tìm kiếm vào localStorage
     * author: NvtDuong
     * createdDate: 13/12/25
     * @param keyword 
     */
    saveHistory(keyword) {
      const me = this;
      let history = [...me.searchHistory];

      // bỏ trùng
      history = history.filter(k => k !== keyword);

      // thêm lên đầu
      history.unshift(keyword);

      // giới hạn 6 từ
      history = history.slice(0, 6);

      // cập nhật state
      me.searchHistory = history;

      // lưu vào localStorage
      localStorage.setItem("search_history", JSON.stringify(history));
    },
  
    /**
     * Đọc lịch sử tìm kiếm từ localStorage
     * author: NvtDuong
     * createdDate: 13/12/25
     */
    loadHistory() {
      const me = this;
      const raw = localStorage.getItem("search_history");
      me.searchHistory = raw ? JSON.parse(raw) : [];
    },

    /**
    * Load thêm truyện (scroll)
    * author: NvtDuong
    * createdDate: 13/12/25
    */
    loadMore() {
      const me = this;
      // đang load thì không load tiếp
      if (me.isLoading) return;

      // đã hiển thị hết kết quả
      if (me.shown.length >= me.results.length) return;

      me.isLoading = true;

      // giả lập delay để UX mượt hơn
      setTimeout(() => {
        // lấy batch tiếp theo
        const next = me.results.slice(
          me.shown.length,
          me.shown.length + me.batchSize
        );

        // thêm vào danh sách đang hiển thị
        me.shown.push(...next);
        me.isLoading = false;
      }, 300);
    },

    /**
     * Emit truyện được chọn lên component cha
     * author: NvtDuong
     * createdDate: 13/12/25
     * @param {Object} m - truyện được click
     */
    selectManga(m) {
      const me = this;
      me.$emit("select", m);
    },

    /**
     * Xử lý sự kiện scroll container -> Khi scroll gần đáy thì gọi loadMore()
     * author: NvtDuong
     * createdDate: 14/12/25
     */
    onScroll() {
      const me = this;
      const el = me.$refs.container;
      if (!el) return;

      // kiểm tra đã cuộn gần đáy chưa (cách đáy 150px)
      const nearBottom =
        el.scrollTop + el.clientHeight + 150 >= el.scrollHeight;

      if (nearBottom) {
        me.loadMore();
      }
    },

    /**
     * Format ngày từ ISO string sang DD/MM/YYYY
     * @param {String} dateString
     * @returns {String}
     * author: NvtDuong
     * createdDate: 14/12/25
     */
    formatDate(dateString) {
      if (!dateString) return "";
      const d = new Date(dateString);
      return (
        String(d.getDate()).padStart(2, "0") +
        "/" +
        String(d.getMonth() + 1).padStart(2, "0") +
        "/" +
        d.getFullYear()
      );
    },

    /**
     * Xóa lịch sử tìm kiếm
     * author: NvtDuong
     * createdDate: 14/12/25
     */
    removeHistory(keyword) {
      const me = this;
      const history = me.searchHistory.filter(k => k !== keyword);
      me.searchHistory = history;
      localStorage.setItem("search_history", JSON.stringify(history));
    },
  },

  /**
   * Khi keyword thay đổi từ component cha -> tự động gọi lại hàm tìm kiếm
   */
  watch: {
    keyword() {
      this.loadSearch();
    }
  },

  /**
   * Nếu có keyword sẵn thì load dữ liệu
   * author: NvtDuong
   * createdDate: 13/12/25
   */
  mounted() {
    const me = this;
    const el = me.$refs.container;
    //ref bị sai tên -> lỗi -> DOM chưa sẵn sàng
    if (el) {
      // Gắn sự kiện scroll cho container
      // Khi kéo chuột -> gọi onScroll()
      el.addEventListener("scroll", me.onScroll);
    }
    if (me.keyword) {
      me.loadSearch();
    }
  },

  /**
   * Nếu KHÔNG remove:
    mỗi lần vào trang → gắn thêm 1 listener
    scroll 1 lần → gọi onScroll nhiều lần
    loadMore bị gọi liên tục
   */
  beforeUnmount() {
    const me = this;
    const el = me.$refs.container;
    //ref bị sai tên -> lỗi -> DOM chưa sẵn sàng
    if (el) {
      el.removeEventListener("scroll", me.onScroll);
    }
  },

};

</script>

<style scoped>
.filtered-container {
  padding: 20px;
  height: 80vh; /* để container scroll */
  overflow-y: auto;
}
.title { 
  font-size: 22px; 
  font-weight: bold; 
  margin-bottom: 16px; 
}
.loaded-info { 
  margin-bottom: 10px; 
  color: #555; 
  font-size: 14px; 
  text-align: center; 
}
.manga-grid { 
  display: grid; 
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); 
  gap: 16px; 
}
.manga-item { 
  display: flex; 
  flex-direction: column; 
  border-radius: 8px; 
  overflow: hidden; 
  background: #fafafa; 
  border: 1px solid #eee; 
  cursor: pointer; 
  transition: 0.2s; 
}
.manga-item:hover { 
  transform: translateY(-2px); 
  box-shadow: 0 4px 12px rgba(0,0,0,0.15); 
}
.thumbnail { 
  width: 100%; 
  height: 220px; 
  object-fit: cover; 
  background: #ddd; 
}
.info { 
  padding: 10px; 
  display: flex; 
  flex-direction: column; 
  gap: 4px; 
}
.info h3 { 
  font-size: 16px; 
  margin: 0; 
  color: #2f5492; 
}
.info p { 
  margin: 0; 
  font-size: 13px; 
  color: #555; 
}
.loading { 
  margin-top: 20px; 
  text-align: center; 
  font-size: 14px; 
}
.loader { 
  width: 32px; 
  height: 32px; 
  border: 4px solid #ccc; 
  border-top-color: #3498db; 
  border-radius: 50%; 
  margin: 0 auto 8px; 
  animation: spin 0.7s linear infinite; 
}
@keyframes spin { 
  to { 
  transform: rotate(360deg); 
} }
.no-result, .end-text { 
  margin-top: 20px; 
  text-align: center; 
  color: #555; 
  }
</style>
