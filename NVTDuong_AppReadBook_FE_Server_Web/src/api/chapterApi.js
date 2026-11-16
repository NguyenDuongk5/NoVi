import baseApi from "./baseApi";

const chapterApi = {
  getAll: () => baseApi.get("/Chapter/all"),

  getById: (id) => baseApi.get(`/Chapter/${id}`),

  insert: (data) => baseApi.post("/Chapter", data),

  update: (chapter) => baseApi.put(`/Chapter/${chapter.chapter_id}`,chapter),
  
  delete: (id) => baseApi.delete("/Chapter/delete", id),

  count: () => baseApi.get("/Chapter/count"),

  countToday: () => baseApi.get("/Chapter/count-today"),
};

export default chapterApi;
export { chapterApi };
